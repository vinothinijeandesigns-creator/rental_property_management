class EmailValidator {
  /// Validates email format for TextFormField validator callback.
  static String? call(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Returns true if the email string is valid.
  static bool validate(String email) {
    final emailRegex = RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$');
    return emailRegex.hasMatch(email.trim());
  }
}
