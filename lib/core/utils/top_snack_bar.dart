import 'package:flutter/material.dart';

/// Displays a floating snackbar notification at the top of the screen
/// so that it never obscures bottom toolbars or catalog drawers.
void showTopSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  IconData? icon,
  Duration duration = const Duration(seconds: 3),
  Color? backgroundColor,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.hideCurrentSnackBar();

  final mediaQuery = MediaQuery.of(context);
  final topPadding = mediaQuery.padding.top;
  final screenHeight = mediaQuery.size.height;

  // Calculate bottom margin so the snackbar floats cleanly near the top
  final bottomMargin = (screenHeight - topPadding - 110).clamp(16.0, screenHeight - 60.0);

  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
          ] else if (isError) ...[
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
          ] else ...[
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        bottom: bottomMargin,
        left: 20,
        right: 20,
      ),
      dismissDirection: DismissDirection.up,
      backgroundColor: backgroundColor ??
          (isError ? const Color(0xFFD32F2F) : const Color(0xFF1E293B)),
      duration: duration,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
