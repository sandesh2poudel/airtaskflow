// lib/core/utils/validators.dart
class Validators {
  static String? required(String? value, [String field = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) return 'Username is required';
    if (value.trim().length < 3) return 'Username must be at least 3 characters';
    if (value.contains(' ')) return 'Username cannot contain spaces';
    return null;
  }

  static String? password(String? value, {bool isRequired = true}) {
    if (!isRequired && (value == null || value.isEmpty)) return null;
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? url(String? value) {
    if (value == null || value.isEmpty) return null;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      return 'Please enter a valid URL (https://...)';
    }
    return null;
  }

  static String? number(String? value, [String field = 'Amount']) {
    if (value == null || value.isEmpty) return null;
    if (double.tryParse(value) == null) return '$field must be a valid number';
    return null;
  }

  static String? positiveNumber(String? value, [String field = 'Amount']) {
    final err = number(value, field);
    if (err != null) return err;
    if (value != null && value.isNotEmpty && (double.tryParse(value) ?? 0) <= 0) {
      return '$field must be greater than 0';
    }
    return null;
  }

  static String? whatsapp(String? value) {
    if (value == null || value.isEmpty) return null;
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(cleaned)) {
      return 'Enter a valid phone number';
    }
    return null;
  }
}
