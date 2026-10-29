import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color primaryColor;
  final Color? accentColor;
  final double height;
  final double borderRadius;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.primaryColor = const Color(0xFF808000), // App Olive Green
    this.accentColor,
    this.height = 52,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? primaryColor;

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: primaryColor,
          gradient: accentColor != null
              ? LinearGradient(
                  colors: onPressed == null || isLoading
                      ? [
                          primaryColor.withValues(alpha: 0.6),
                          effectiveAccent.withValues(alpha: 0.6),
                        ]
                      : [
                          primaryColor,
                          effectiveAccent,
                        ],
                )
              : null,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: onPressed == null || isLoading
              ? []
              : [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}
