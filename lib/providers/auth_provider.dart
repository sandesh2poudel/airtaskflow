// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

enum AuthState { idle, loading, authenticated, error }

class AuthProvider extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();

  UserModel? _currentUser;
  AuthState _state = AuthState.idle;
  String _errorMessage = '';

  UserModel? get currentUser => _currentUser;
  AuthState get state => _state;
  String get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthState.authenticated && _currentUser != null;

  Future<bool> login(String username, String password) async {
    _state = AuthState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final user = await _service.loginUser(username.trim(), password.trim());
      if (user != null) {
        _currentUser = user;
        _state = AuthState.authenticated;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Wrong username or password.';
        _state = AuthState.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Connection error. Please try again.';
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    _state = AuthState.idle;
    _errorMessage = '';
    notifyListeners();
  }
}
