import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../l10n/localization.dart';
import '../application/receipt_layout.dart';

/// Lazily painted preview shares TextPainter geometry and lines with ESC/POS
/// rasterization; screen scaling never changes the physical template dimensions.
class ReceiptPreview extends StatefulWidget {
  const ReceiptPreview({super.key, required this.layout, this.logo});
  final ReceiptLayout layout;
  final Uint8List? logo;
  @override
  State<ReceiptPreview> createState() => _ReceiptPreviewState();
}

class _ReceiptPreviewState extends State<ReceiptPreview> {
  ui.Image? image;
  bool failed = false;
  int generation = 0;
  ReceiptLayout get layout => widget.layout;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(ReceiptPreview old) {
    super.didUpdateWidget(old);
    if (old.logo != widget.logo || old.layout != layout) load();
  }

  Future<void> load() async {
    final current = ++generation;
    image?.dispose();
    image = null;
    failed = false;
    if (widget.logo == null || !layout.profile.logo) return;
    try {
      final decoded = await layout.decodeLogo(widget.logo!);
      if (!mounted || current != generation) {
        decoded.dispose();
        return;
      }
      setState(() => image = decoded);
    } catch (_) {
      if (mounted && current == generation) setState(() => failed = true);
    }
  }

  @override
  void dispose() {
    generation++;
    image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = (box.maxWidth / layout.profile.dots).clamp(0.1, 1.0);
      return ListView.builder(
        itemCount: layout.lines.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            if (failed) return Text(tr(context, 'm5OperationFailed'));
            if (image == null) return const SizedBox.shrink();
            return Align(
              alignment: Alignment.topCenter,
              child: CustomPaint(
                size: Size(layout.profile.dots * scale, image!.height * scale),
                painter: _LogoPainter(layout, image!, scale),
              ),
            );
          }
          final line = layout.lines[index - 1], text = layout.painter(line);
          final height = text.height.ceil() + layout.profile.lineGap;
          text.dispose();
          return Align(
            alignment: Alignment.topCenter,
            child: CustomPaint(
              size: Size(layout.profile.dots * scale, height * scale),
              painter: _PreviewPainter(layout, line, scale),
            ),
          );
        },
      );
    },
  );
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.layout, this.image, this.scale);
  final ReceiptLayout layout;
  final ui.Image image;
  final double scale;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(Colors.white, BlendMode.src);
    canvas.save();
    canvas.scale(scale);
    canvas.drawImage(image, Offset(layout.logoX(image.width), 0), Paint());
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.layout != layout || old.image != image || old.scale != scale;
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.layout, this.line, this.scale);
  final ReceiptLayout layout;
  final ReceiptLine line;
  final double scale;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    canvas.save();
    canvas.scale(scale);
    final text = layout.painter(line);
    text.paint(canvas, ui.Offset(layout.profile.x.toDouble(), 0));
    text.dispose();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PreviewPainter old) =>
      old.layout != layout || old.line != line || old.scale != scale;
}
