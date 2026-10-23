import 'package:flutter/material.dart';

/// Centralized SnackBar helper providing a consistent, floating, rounded
/// alert design with leading icons across the application.
class AppSnackBar {
  /// Shows a floating red error SnackBar matching the app's error UI design.
  static void showError(BuildContext context, String message, {Duration duration = const Duration(seconds: 4)}) {
    if (!context.mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: duration,
      ),
    );
  }

  /// Shows a floating green success SnackBar.
  static void showSuccess(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) {
    if (!context.mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: duration,
      ),
    );
  }

  /// Shows a floating alert SnackBar matching the login screen red error UI design.
  static void showWarning(BuildContext context, String message, {Duration duration = const Duration(seconds: 4)}) {
    showError(context, message, duration: duration);
  }

  /// Shows a floating dark info SnackBar.
  static void showInfo(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) {
    if (!context.mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF374151),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: duration,
      ),
    );
  }

  /// Formats raw error exceptions into user-friendly messages.
  static String cleanErrorMessage(dynamic e) {
    if (e == null) return 'Something went wrong. Please try again.';
    final error = e.toString().toLowerCase();

    if (error.contains('socketexception') ||
        error.contains('failed host lookup') ||
        error.contains('clientexception') ||
        error.contains('network is unreachable') ||
        error.contains('connection refused') ||
        error.contains('connection timed out') ||
        error.contains('network error')) {
      return 'Unable to connect. Please check your internet connection.';
    }

    if (error.contains('invalid login credentials') ||
        error.contains('invalid credentials')) {
      return 'Incorrect email or password. Please try again.';
    }

    if (error.contains('email not confirmed')) {
      return 'Please verify your email address before logging in.';
    }

    if (error.contains('too many requests') ||
        error.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }

    if (error.contains('already registered') || error.contains('user already exists')) {
      return 'An account with this email already exists.';
    }

    String msg = e.toString();
    if (msg.startsWith('Exception: ')) {
      msg = msg.substring(11);
    }
    return msg;
  }
}
