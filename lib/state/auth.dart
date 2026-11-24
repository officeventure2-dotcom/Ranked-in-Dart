import 'package:flutter/foundation.dart';

import '../api/api_client.dart';

class SignedInUser {
  const SignedInUser(this.id, this.name, this.email);
  final String id;
  final String name;
  final String email;
}

/// Sign-in state backed by /api/auth/* on the Worker.
class Auth extends ChangeNotifier {
  Auth(this.api);
  final ApiClient api;
  SignedInUser? user;

  static SignedInUser _parse(Map<String, dynamic> j) {
    final u = j['user'] as Map<String, dynamic>;
    return SignedInUser(u['id'] as String, u['name'] as String, u['email'] as String);
  }

  /// Restores the saved session; a 401 just means signed out.
  Future<void> restore() async {
    try {
      user = _parse(await api.get('/api/auth/me'));
    } on ApiException {
      user = null;
    }
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    user = _parse(await api.post('/api/auth/signin', {'email': email, 'password': password}));
    notifyListeners();
  }

  Future<void> signUp(String name, String email, String password) async {
    user = _parse(await api.post('/api/auth/signup', {'name': name, 'email': email, 'password': password}));
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await api.post('/api/auth/signout');
    } finally {
      user = null;
      notifyListeners();
    }
  }
}
