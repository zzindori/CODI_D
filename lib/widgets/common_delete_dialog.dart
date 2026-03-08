import 'package:flutter/material.dart';

Future<bool> showCommonDeleteDialog(
  BuildContext context, {
  required String title,
  required String message,
  String cancelText = '취소',
  String confirmText = '확인',
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => _CommonDeleteDialog(
      title: title,
      message: message,
      cancelText: cancelText,
      confirmText: confirmText,
    ),
  );

  return result ?? false;
}

class _CommonDeleteDialog extends StatelessWidget {
  final String title;
  final String message;
  final String cancelText;
  final String confirmText;

  const _CommonDeleteDialog({
    required this.title,
    required this.message,
    required this.cancelText,
    required this.confirmText,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 28),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 46, 18, 14),
                  child: Column(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 15,
                          color: colors.onSurfaceVariant,
                          height: 1.45,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: colors.outlineVariant),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(18),
                            ),
                          ),
                        ),
                        child: Text(
                          cancelText,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 1,
                      height: 48,
                      child: ColoredBox(color: colors.outlineVariant),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              bottomRight: Radius.circular(18),
                            ),
                          ),
                        ),
                        child: Text(
                          confirmText,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: colors.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surface,
              border: Border.all(color: colors.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: colors.error,
              size: 36,
            ),
          ),
        ],
      ),
    );
  }
}
