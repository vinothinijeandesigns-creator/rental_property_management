import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_snackbar.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? _user;
  Session? _session;
  bool _isLoading = false;
  String? _lastError;
  StreamSubscription<AuthState>? _authSubscription;

  AuthProvider() {
    _session = _supabase.auth.currentSession;
    _user = _supabase.auth.currentUser;

    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      _session = data.session;
      _user = data.session?.user;
      notifyListeners();
    });
  }

  User? get user => _user;
  Session? get session => _session;
  bool get isAuthenticated => _session != null;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  void clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }

  /// Sign in with email and password
  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      _session = response.session;
      _user = response.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _lastError = _formatAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = AppSnackBar.cleanErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with Google via Supabase OAuth
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final success = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? null
            : 'io.supabase.rentalpropertymanagement://login-callback',
      );
      _isLoading = false;
      notifyListeners();
      return success;
    } on AuthException catch (e) {
      _lastError = _formatAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = AppSnackBar.cleanErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Step 1: Request password reset code sent to email
  Future<bool> requestPasswordReset(String email) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      await _supabase.auth.resetPasswordForEmail(email.trim());
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _lastError = _formatAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = AppSnackBar.cleanErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Step 2: Verify reset OTP code and set new password
  Future<bool> verifyResetCodeAndSetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      // 1. Verify OTP with recovery type
      await _supabase.auth.verifyOTP(
        email: email.trim(),
        token: code.trim(),
        type: OtpType.recovery,
      );

      // 2. Set the new password for current recovered session
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _lastError = _formatAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = AppSnackBar.cleanErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Admin/User Sign up
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': name.trim()},
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _lastError = _formatAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = AppSnackBar.cleanErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _supabase.auth.signOut();
    } finally {
      _session = null;
      _user = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  String _formatAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    final code = e.code?.toLowerCase() ?? '';

    if (msg.contains('provider is not enabled') ||
        msg.contains('unsupported provider') ||
        msg.contains('provider not enabled')) {
      return 'Google sign-in is not enabled in your Supabase project. Please enable Google provider in the Supabase Dashboard.';
    }
    if (msg.contains('invalid login credentials') || msg.contains('invalid credentials')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please verify your email address before logging in.';
    }
    if (msg.contains('too many requests') || msg.contains('rate limit') || code.contains('over_request_rate_limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (msg.contains('user not found')) {
      return 'No account found. Please check your details or sign up.';
    }
    if (msg.contains('token has expired') || msg.contains('otp has expired')) {
      return 'The reset code has expired. Please request a new code.';
    }
    if (msg.contains('invalid token') || msg.contains('token is invalid') || msg.contains('otp')) {
      return 'Invalid reset code. Please check and try again.';
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return 'Unable to connect. Please check your internet connection.';
    }
    return e.message.isNotEmpty ? e.message : 'Authentication failed. Please try again.';
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
