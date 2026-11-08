part of 'receipt_photo_screen.dart';

/// One preview uses the same native owner as barcode scanning. The capture is
/// held in this route until Save and discarded on background or authorization loss.
class _ReceiptPhotoCaptureScreen extends StatefulWidget {
  const _ReceiptPhotoCaptureScreen();

  @override
  State<_ReceiptPhotoCaptureScreen> createState() =>
      _ReceiptPhotoCaptureScreenState();
}

class _ReceiptPhotoCaptureScreenState extends State<_ReceiptPhotoCaptureScreen>
    with WidgetsBindingObserver {
  final _scope = RouteInputScope();
  final _permissions = NativeBarcodeCamera();
  MethodChannel? _view;
  ReceiptPhotoAsset? _asset;
  MemoryImage? _image;
  StreamSubscription<int>? _session;
  int? _generation;
  bool _visible = false, _ready = false, _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope.attach(
      context.read<RouteObserver<ModalRoute<dynamic>>?>(),
      ModalRoute.of(context),
    );
    if (_generation != null) return;
    final app = context.read<AppServices>();
    _generation = app.database.generation;
    _session = app.management.sessionChanges.listen((_) {
      if (mounted && !app.management.isUnlocked) _suspend();
    });
  }

  Future<void> _authorize() async {
    if (!mounted || !_scope.canReceive) {
      throw const AppError('m53ReceiptDraftChanged');
    }
    final app = context.read<AppServices>();
    if (app.database.generation != _generation) {
      throw const AppError('m53ReceiptDraftChanged');
    }
    await app.management.authorizeCurrent(
      capability: ManagementCapability.inventory,
    );
  }

  Future<void> _start() async {
    if (_busy) return;
    final old = _image;
    setState(() {
      _busy = true;
      _image = null;
      _asset = null;
      _error = null;
    });
    unawaited(old?.evict());
    try {
      await _authorize();
      if (!mounted) return;
      final management = context.read<AppServices>().management;
      var status = await _permissions.probe();
      if (!status.available) throw const AppError('m54ReceiptPhotoUnavailable');
      if (!status.permission) {
        status = await management.systemInteraction(
          _permissions.requestPermission,
        );
      }
      if (!status.permission) throw const AppError('m53CameraPermissionDenied');
      await _authorize();
      if (mounted) setState(() => _visible = true);
    } catch (e) {
      _report(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _report(Object error) {
    if (!mounted) return;
    setState(
      () =>
          _error = error is PlatformException || error is MissingPluginException
          ? 'm54ReceiptPhotoUnavailable'
          : safeError(error),
    );
  }

  Future<void> _attach(int id) async {
    if (!mounted || !_visible) return;
    final channel = MethodChannel('kasir_app/barcode_camera/$id');
    _view = channel;
    channel.setMethodCallHandler((call) async {
      if (!mounted || _view != channel || !_scope.canReceive) return;
      if (call.method == 'started') setState(() => _ready = true);
      if (call.method == 'error') {
        _suspend();
        _report(const AppError('m54ReceiptPhotoUnavailable'));
      }
    });
    try {
      await _authorize();
      if (mounted && _view == channel) {
        await channel.invokeMethod<void>('armPhoto');
      }
    } catch (e) {
      _suspend();
      _report(e);
    }
  }

  Future<void> _releaseView() async {
    final channel = _view;
    _view = null;
    channel?.setMethodCallHandler(null);
    try {
      await channel?.invokeMethod<void>('pause');
    } on PlatformException {
      // Platform view removal may already have released the camera.
    } on MissingPluginException {
      // The platform view can disappear before a lifecycle callback completes.
    }
  }

  Future<void> _take() async {
    final channel = _view;
    if (_busy || !_ready || channel == null || !_scope.canReceive) return;
    final guard = _scope.capture();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _authorize();
      guard();
      final bytes = await channel.invokeMethod<Uint8List>('capturePhoto');
      guard();
      if (bytes == null) throw ReceiptPhotoAsset.invalid;
      final photo = ReceiptPhotoAsset.fromJpeg(bytes);
      await _releaseView();
      guard();
      setState(() {
        _visible = false;
        _ready = false;
        _asset = photo;
        _image = MemoryImage(photo.jpeg);
      });
    } catch (e) {
      _report(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final photo = _asset;
    if (photo == null || _busy) return;
    setState(() => _busy = true);
    try {
      final guard = _scope.capture();
      await _authorize();
      guard();
      if (mounted && _asset == photo) Navigator.pop(context, photo);
    } catch (e) {
      _report(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _suspend() {
    final old = _image;
    unawaited(_releaseView());
    unawaited(old?.evict());
    if (mounted) {
      setState(() {
        _visible = false;
        _ready = false;
        _asset = null;
        _image = null;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _suspend();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scope.dispose();
    unawaited(_session?.cancel());
    unawaited(_releaseView());
    unawaited(_permissions.dispose());
    unawaited(_image?.evict());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    capability: ManagementCapability.inventory,
    child: Scaffold(
      appBar: AppBar(title: Text(tr(context, 'm54ReceiptPhotoTake'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error case final error?) Text(tr(context, error)),
            Text(tr(context, 'm54ReceiptPhotoCaptureHelp')),
            if (_visible)
              SizedBox(
                height: 410,
                child: AndroidView(
                  viewType: 'kasir_app/barcode_camera',
                  creationParams: const {'receiptPhoto': true},
                  creationParamsCodec: const StandardMessageCodec(),
                  onPlatformViewCreated: _attach,
                ),
              ),
            if (_visible)
              FilledButton(
                onPressed: !_ready || _busy ? null : _take,
                child: Text(tr(context, 'm54ReceiptPhotoTake')),
              ),
            if (_image case final image?) ...[
              SizedBox(
                height: 320,
                child: Center(child: _PhotoPreview(image: image)),
              ),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(tr(context, 'save')),
              ),
              TextButton(
                onPressed: _busy ? null : _start,
                child: Text(tr(context, 'm54ReceiptPhotoRetake')),
              ),
            ] else if (!_visible)
              FilledButton(
                onPressed: _busy ? null : _start,
                child: Text(tr(context, 'm54ReceiptPhotoStart')),
              ),
          ],
        ),
      ),
    ),
  );
}
