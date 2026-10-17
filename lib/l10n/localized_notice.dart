import 'package:flutter/material.dart';
import 'localization.dart';

/// Snackbar overlays rebuild against Localizations even after their originating
/// form is gone. Undo remains single-use and retains the service's time limit.
class LocalizedNotice extends StatefulWidget {
  const LocalizedNotice({super.key, required this.messageKey, this.onUndo});
  final String messageKey;
  final VoidCallback? onUndo;
  @override
  State<LocalizedNotice> createState() => _LocalizedNoticeState();
}

class _LocalizedNoticeState extends State<LocalizedNotice> {
  bool used = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(message(context, widget.messageKey)),
      if (widget.onUndo != null)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: used
                ? null
                : () {
                    setState(() => used = true);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    widget.onUndo!();
                  },
            child: Text(tr(context, 'undo')),
          ),
        ),
    ],
  );
}
