import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/presentation/route_input_scope.dart';
import '../../../l10n/localization.dart';
import '../../barcode/application/native_barcode_camera.dart';
import '../../management/domain/management_role.dart';
import '../../management/presentation/management_gate.dart';
import '../../suppliers/presentation/supplier_finance_forms.dart';
import '../application/inventory_service.dart';
import '../domain/receipt_photo.dart';

part 'receipt_photo_capture_screen.dart';

typedef _Pages = ({int revision, bool editable, List<ReceiptPhotoPage> pages});

class ReceiptPhotoScreen extends StatefulWidget {
  const ReceiptPhotoScreen({super.key, required this.id, required this.posted});
  final EntityId id;
  final bool posted;

  @override
  State<ReceiptPhotoScreen> createState() => _ReceiptPhotoScreenState();
}

class _ReceiptPhotoScreenState extends State<ReceiptPhotoScreen> {
  final _scope = RouteInputScope();
  _Pages? _pages;
  String? _error;
  int? _generation;
  bool _busy = false;

  AppServices get _app => context.read<AppServices>();
  ManagementCapability get _capability => widget.posted
      ? ManagementCapability.owner
      : ManagementCapability.inventory;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope.attach(
      context.read<RouteObserver<ModalRoute<dynamic>>?>(),
      ModalRoute.of(context),
    );
    if (_generation != null) return;
    _generation = _app.database.generation;
    _run(_load);
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_app.database.generation != _generation) {
        throw const AppError('m53ReceiptDraftChanged');
      }
      await work();
    } catch (e) {
      if (mounted) setState(() => _error = safeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    final app = _app;
    final pages = await app.inventory.receiptPhotoPages(widget.id);
    if (!mounted) return;
    if (app.database.generation != _generation) {
      throw const AppError('m53ReceiptDraftChanged');
    }
    setState(() => _pages = pages);
  }

  Future<void> _capture([ReceiptPhotoPage? page]) => _run(() async {
    final app = _app;
    final revision = _pages!.revision;
    final result = await Navigator.of(context).push<ReceiptPhotoAsset>(
      MaterialPageRoute(builder: (_) => const _ReceiptPhotoCaptureScreen()),
    );
    if (!mounted || result == null || !_scope.canReceive) return;
    if (app.database.generation != _generation) {
      throw const AppError('m53ReceiptDraftChanged');
    }
    await app.inventory.saveReceiptPhoto(
      widget.id,
      revision,
      result,
      replace: page?.id,
      requireIntent: _scope.capture(),
    );
    if (mounted) await _load();
  });

  Future<void> _rotate(ReceiptPhotoPage page) => _run(() async {
    await _app.inventory.rotateReceiptPhoto(
      widget.id,
      _pages!.revision,
      page.id,
      requireIntent: _scope.capture(),
    );
    if (mounted) await _load();
  });

  Future<void> _remove(ReceiptPhotoPage page) => _run(() async {
    final revision = _pages!.revision;
    final accepted = await confirmSupplierFact(
      context,
      tr(context, 'm54ReceiptPhotoDeleteHelp'),
      capability: _capability,
    );
    if (!mounted || !accepted || !_scope.canReceive) return;
    if (_app.database.generation != _generation) {
      throw const AppError('m53ReceiptDraftChanged');
    }
    await _app.inventory.removeReceiptPhoto(
      widget.id,
      revision,
      page.id,
      requireIntent: _scope.capture(),
    );
    if (mounted) await _load();
  });

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages?.pages ?? const <ReceiptPhotoPage>[];
    final editable = _pages?.editable == true;
    return ManagementGate(
      capability: _capability,
      child: Scaffold(
        appBar: AppBar(title: Text(tr(context, 'm54ReceiptPhotos'))),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_error case final error?) Text(tr(context, error)),
              if (editable)
                FilledButton(
                  key: const ValueKey('receipt-photo-capture'),
                  onPressed: _busy || pages.length >= ReceiptPhotoAsset.maxPages
                      ? null
                      : _capture,
                  child: Text(tr(context, 'm54ReceiptPhotoTake')),
                ),
              if (_pages != null && pages.isEmpty)
                Text(tr(context, 'm54ReceiptPhotoEmpty')),
              for (final (index, page) in pages.indexed)
                Card(
                  child: ListTile(
                    key: ValueKey('receipt-photo-${page.id.value}'),
                    title: Text(
                      '${tr(context, 'm54ReceiptPhotoPage')} ${index + 1}',
                    ),
                    subtitle: Text(
                      '${page.width} × ${page.height} · ${(page.bytes / 1024).ceil()} KiB',
                    ),
                    onTap: _busy
                        ? null
                        : () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => _ReceiptPhotoViewer(
                                draft: widget.id,
                                page: page,
                                capability: _capability,
                              ),
                            ),
                          ),
                    trailing: !editable
                        ? null
                        : PopupMenuButton<String>(
                            enabled: !_busy,
                            onSelected: (action) {
                              switch (action) {
                                case 'retake':
                                  _capture(page);
                                case 'rotate':
                                  _rotate(page);
                                case 'delete':
                                  _remove(page);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'retake',
                                child: Text(
                                  tr(context, 'm54ReceiptPhotoRetake'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'rotate',
                                child: Text(
                                  tr(context, 'm54ReceiptPhotoRotate'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(tr(context, 'delete')),
                              ),
                            ],
                          ),
                  ),
                ),
              if (!_busy && _error != null)
                TextButton(
                  onPressed: () => _run(_load),
                  child: Text(tr(context, 'm53SupplierFirst')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptPhotoViewer extends StatefulWidget {
  const _ReceiptPhotoViewer({
    required this.draft,
    required this.page,
    required this.capability,
  });
  final EntityId draft;
  final ReceiptPhotoPage page;
  final ManagementCapability capability;

  @override
  State<_ReceiptPhotoViewer> createState() => _ReceiptPhotoViewerState();
}

class _ReceiptPhotoViewerState extends State<_ReceiptPhotoViewer> {
  MemoryImage? _image;
  late final Future<MemoryImage> _load = _read();

  Future<MemoryImage> _read() async {
    final app = context.read<AppServices>();
    final generation = app.database.generation;
    final asset = await app.inventory.receiptPhoto(
      widget.draft,
      widget.page.id,
    );
    if (!mounted || generation != app.database.generation) {
      throw const AppError('m53ReceiptDraftChanged');
    }
    return _image = MemoryImage(asset.jpeg);
  }

  @override
  void dispose() {
    unawaited(_image?.evict());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    capability: widget.capability,
    child: Scaffold(
      appBar: AppBar(title: Text(tr(context, 'm54ReceiptPhotoPreview'))),
      body: SafeArea(
        child: FutureBuilder<MemoryImage>(
          future: _load,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(tr(context, safeError(snapshot.error!))),
              );
            }
            final image = snapshot.data;
            if (image == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(
              child: _PhotoPreview(image: image, turns: widget.page.rotation),
            );
          },
        ),
      ),
    ),
  );
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.image, this.turns = 0});
  final MemoryImage image;
  final int turns;

  @override
  Widget build(BuildContext context) => InteractiveViewer(
    maxScale: 5,
    child: RotatedBox(
      quarterTurns: turns,
      child: Image(image: image, fit: BoxFit.contain),
    ),
  );
}
