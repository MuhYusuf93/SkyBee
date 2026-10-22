import 'dart:async';
import 'dart:io';
import 'package:kasir_platform/kasir_platform.dart';

/// Output ownership spans an entire receipt, never a single raster chunk.
/// Android reuses the established native semaphore/file lease across engines;
/// a process death releases the OS lock. No payload or job is stored here.
abstract interface class PrinterOutputGate {
  Future<PrinterOutputLease> acquire();
}

abstract interface class PrinterOutputLease {
  Future<void> release();
}

PrinterOutputGate defaultPrinterOutputGate() => Platform.isAndroid
    ? const AndroidPrinterOutputGate()
    : const ProcessPrinterOutputGate();

Future<T> withPrinterOutput<T>(
  PrinterOutputGate gate,
  Future<T> Function() action,
) async {
  final lease = await gate.acquire();
  try {
    return await action();
  } finally {
    await lease.release();
  }
}

final class AndroidPrinterOutputGate implements PrinterOutputGate {
  const AndroidPrinterOutputGate([this.platform = const KasirPlatform()]);
  final KasirPlatform platform;
  @override
  Future<PrinterOutputLease> acquire() async => _AndroidOutputLease(
    platform,
    await platform.call<String>('acquire', {'name': 'printer-output'}),
  );
}

final class _AndroidOutputLease implements PrinterOutputLease {
  _AndroidOutputLease(this.platform, this.token);
  final KasirPlatform platform;
  final String token;
  bool _released = false;
  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    await platform.release(token);
  }
}

/// Test/desktop equivalent shares FIFO ownership across service instances in
/// this isolate. Android always uses the native cross-engine implementation.
final class ProcessPrinterOutputGate implements PrinterOutputGate {
  const ProcessPrinterOutputGate();
  static Future<void> _tail = Future.value();
  @override
  Future<PrinterOutputLease> acquire() async {
    final release = Completer<void>();
    final previous = _tail;
    _tail = previous.then((_) => release.future);
    await previous;
    return _ProcessOutputLease(release);
  }
}

final class _ProcessOutputLease implements PrinterOutputLease {
  _ProcessOutputLease(this.done);
  final Completer<void> done;
  @override
  Future<void> release() async {
    if (!done.isCompleted) done.complete();
  }
}
