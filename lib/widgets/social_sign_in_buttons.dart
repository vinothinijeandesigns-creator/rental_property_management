import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_snackbar.dart';
import 'google_logo.dart';

class SocialSignInButtons extends StatefulWidget {
  final VoidCallback? onSignedIn;

  const SocialSignInButtons({
    super.key,
    this.onSignedIn,
  });

  @override
  State<SocialSignInButtons> createState() => _SocialSignInButtonsState();
}

class _SocialSignInButtonsState extends State<SocialSignInButtons> {
  bool _isGoogleLoading = false;

  Future<void> _handleGoogleSignIn() async {
    if (_isGoogleLoading) return;
    setState(() => _isGoogleLoading = true);

    try {
      final auth = context.read<AuthProvider>();
      final success = await auth.signInWithGoogle();

      if (!mounted) return;
      setState(() => _isGoogleLoading = false);

      if (success) {
        if (widget.onSignedIn != null) {
          widget.onSignedIn!();
        }
      } else if (auth.lastError != null) {
        AppSnackBar.showError(context, auth.lastError!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGoogleLoading = false);
      AppSnackBar.showError(context, AppSnackBar.cleanErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Divider(
                color: Color(0xFFE2E8F0),
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'OR CONTINUE WITH',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            const Expanded(
              child: Divider(
                color: Color(0xFFE2E8F0),
                thickness: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1E293B),
              side: const BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1.2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _isGoogleLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF808000)),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GoogleLogo(size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
