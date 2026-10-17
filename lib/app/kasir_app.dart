import 'package:kasir_app/l10n/localization.dart';
import '../features/settings/presentation/locale_provider.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/database/database_coordinator.dart';
import '../features/foundation/application/foundation_service.dart';
import '../features/foundation/presentation/foundation_controller.dart';
import '../features/foundation/presentation/cashier_shell.dart';
import '../features/cashier/presentation/cashier_screen.dart';
import 'theme.dart';
import 'app_services.dart';
import '../features/management/presentation/management_session_provider.dart';
import '../data/database/database_security_error.dart';
import '../features/alerts/presentation/alerts_screen.dart';
import 'm5_runtime.dart';
import 'native_licenses.dart';

/// Composition root: shared services are dependencies, never shared feature
/// state. Production owns the M3 cashier flow; injected readiness retains the
/// M1 shell solely for compatibility/regression of startup boundaries.
class KasirApp extends StatelessWidget {
  const KasirApp({super.key, this.foundationService, this.services});
  final FoundationReadiness? foundationService;
  final AppServices? services;
  @override
  Widget build(BuildContext context) {
    registerNativeLicenses();
    return foundationService == null
        ? _ManagementApp(services: services)
        : Provider<FoundationReadiness>(
            create: (_) =>
                foundationService ??
                FoundationService(openDatabase: DatabaseCoordinator.android),
            dispose: (_, service) => unawaited(service.dispose()),
            child: MaterialApp(
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              localeResolutionCallback: (device, _) =>
                  LocaleProvider.resolve(device ?? const Locale('en'), null),
              onGenerateTitle: (context) => tr(context, 'cashier'),
              debugShowCheckedModeBanner: false,
              theme: kasirTheme(),
              home: Builder(
                builder: (context) => ChangeNotifierProvider(
                  create: (_) =>
                      FoundationController(context.read<FoundationReadiness>())
                        ..check(),
                  child: const CashierShell(),
                ),
              ),
            ),
          );
  }
}

/// Startup resolves one database dependency; feature state remains lazy/scoped.
class _ManagementApp extends StatefulWidget {
  const _ManagementApp({this.services});
  final AppServices? services;
  @override
  State<_ManagementApp> createState() => _ManagementAppState();
}

class _ManagementAppState extends State<_ManagementApp> {
  late Future<AppServices> _future;
  DatabaseCoordinator? _owned;
  Map<String, Object?> _preferences = {};
  bool _disposed = false;
  M5Runtime? _runtime;
  AppServices? _activeServices;
  StreamSubscription<DatabaseReplacement>? _replacements;
  GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();
  bool _pendingAlert = false;
  String? _replacementNotice;
  void _openAlerts() {
    _pendingAlert = true;
    if (mounted) setState(() {});
  }

  void _bind(AppServices services, {required bool native}) {
    _activeServices = services;
    _replacements ??= services.database.replacements.listen((event) {
      if (_disposed) return;
      _activeServices?.management.lock();
      setState(() {
        _navigator = GlobalKey<NavigatorState>();
        _pendingAlert = false;
        _replacementNotice = event.succeeded
            ? 'm5RestoreComplete'
            : 'm5RestoreOutcomeCheck';
        _future = _reload(services.database, native: native);
      });
    });
    if (native) {
      _runtime = M5Runtime(services, _openAlerts);
      unawaited(_runtime!.start());
    }
  }

  Future<AppServices> _reload(
    DatabaseCoordinator database, {
    required bool native,
  }) async {
    await _runtime?.dispose();
    _runtime = null;
    final services = AppServices(database);
    _preferences = await services.settings.preferences();
    _activeServices = services;
    if (!_disposed && native) {
      try {
        await services.notifications.plugin.cancelAll();
      } catch (_) {
        /* optional Android delivery must not prevent cashier startup */
      }
      _runtime = M5Runtime(services, _openAlerts);
      unawaited(_runtime!.start());
    }
    return services;
  }

  @override
  void initState() {
    super.initState();
    _future = _open();
  }

  Future<AppServices> _open() async {
    if (widget.services != null) {
      _preferences = await widget.services!.settings.preferences();
      _bind(widget.services!, native: false);
      return widget.services!;
    }
    final database = await DatabaseCoordinator.android();
    try {
      await database.read((db) => db.rawQuery('PRAGMA user_version'));
      if (_disposed) {
        await database.close();
        throw StateError('Startup disposed');
      }
      _owned = database;
      final services = AppServices(database);
      _preferences = await services.settings.preferences();
      _bind(services, native: true);
      return services;
    } catch (_) {
      await database.close();
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_replacements?.cancel() ?? Future.value());
    unawaited(_runtime?.dispose() ?? Future.value());
    unawaited(_owned?.close() ?? Future.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppServices>(
    future: _future,
    builder: (context, snapshot) {
      final services = snapshot.data;
      if (services == null ||
          snapshot.connectionState != ConnectionState.done) {
        return MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          localeResolutionCallback: (device, _) =>
              LocaleProvider.resolve(device ?? const Locale('en'), null),
          theme: kasirTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: SafeArea(
                child: Center(
                  child: snapshot.hasError
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(tr(context, 'cannotOpenStorage')),
                            if (snapshot.error is DatabaseSecurityError)
                              Text(
                                tr(
                                  context,
                                  (snapshot.error as DatabaseSecurityError)
                                      .code,
                                ),
                              ),
                            FilledButton(
                              onPressed: () =>
                                  setState(() => _future = _open()),
                              child: Text(tr(context, 'tryAgain')),
                            ),
                          ],
                        )
                      : CircularProgressIndicator(
                          semanticsLabel: tr(context, 'loading'),
                        ),
                ),
              ),
            ),
          ),
        );
      }
      if (_pendingAlert || _replacementNotice != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _navigator.currentState == null) return;
          if (_pendingAlert) {
            _pendingAlert = false;
            _navigator.currentState!.push(
              MaterialPageRoute<void>(builder: (_) => const AlertsScreen()),
            );
          }
          final notice = _replacementNotice;
          if (notice != null) {
            _replacementNotice = null;
            final context = _navigator.currentContext;
            if (context != null) {
              ScaffoldMessenger.maybeOf(
                context,
              )?.showSnackBar(SnackBar(content: Text(tr(context, notice))));
            }
          }
        });
      }
      return MultiProvider(
        key: ObjectKey(services),
        providers: [
          Provider<AppServices>.value(value: services),
          ChangeNotifierProvider(
            create: (_) => LocaleProvider(services.settings, _preferences),
          ),
          ChangeNotifierProvider(
            create: (_) => ManagementSessionProvider(services.management),
            lazy: false,
          ),
          Provider<FoundationReadiness>(
            create: (_) =>
                FoundationService(openDatabase: () async => services.database),
          ),
        ],
        child: Consumer<LocaleProvider>(
          builder: (context, preferences, _) => MaterialApp(
            navigatorKey: _navigator,
            locale: preferences.language == null
                ? null
                : Locale(preferences.language!),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            localeResolutionCallback: (device, _) => LocaleProvider.resolve(
              device ?? const Locale('en'),
              preferences.language,
            ),
            onGenerateTitle: (context) => tr(context, 'cashier'),
            debugShowCheckedModeBanner: false,
            theme: kasirTheme(),
            home: const CashierScreen(),
          ),
        ),
      );
    },
  );
}
