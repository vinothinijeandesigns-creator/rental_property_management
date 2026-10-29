import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/app_snackbar.dart';
import '../utils/email_validator.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/primary_button.dart';
import 'reset_password_screen.dart';

/// Step 1 of password recovery: request a reset code by email.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

// Compatibility alias
typedef ForgotPasswordFieldScreen = ForgotPasswordScreen;

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  static const Color primaryColor = Color(0xFF808000);
  static const Color accentColor = Color(0xFF545A2C);

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final success = await auth.requestPasswordReset(email);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      AppSnackBar.showSuccess(
        context,
        'Reset code sent to $email.',
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(email: email),
        ),
      );
    } else if (auth.lastError != null) {
      AppSnackBar.showError(context, auth.lastError!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: primaryColor,
        title: const Text(
          'Reset Password',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE8EDF5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Icon
                      Center(
                        child: Container(
                          height: 82,
                          width: 82,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [primaryColor, accentColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.lock_reset_rounded,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'Forgot Password',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        "Enter your email and we'll send you a reset code.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Colors.black54,
                        ),
                      ),

                      const SizedBox(height: 28),

                      AuthTextField(
                        label: 'Email',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: primaryColor,
                          size: 20,
                        ),
                        validator: EmailValidator.call,
                      ),

                      const SizedBox(height: 24),

                      PrimaryButton(
                        label: 'Send Reset Code',
                        isLoading: _isLoading,
                        onPressed: _submit,
                      ),

                      const SizedBox(height: 16),

                      TextButton.icon(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Back to Log In'),
                        style: TextButton.styleFrom(
                          foregroundColor: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
