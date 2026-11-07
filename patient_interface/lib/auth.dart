import 'package:flutter/material.dart';
import 'api.dart';
import 'models.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// Thrown when someone signs in to the patient app with a doctor or caregiver account.
class NotPatientAccount implements Exception {
  const NotPatientAccount();
}

/// The signed-in patient. Owns the API client and keeps its session token in [TokenStore].
class AuthSession extends ChangeNotifier {
  AuthSession(this.api, this._tokens) {
    api.onUnauthorized = () {
      if (status == AuthStatus.signedIn) signOut(expired: true);
    };
  }

  final Api api;
  final TokenStore _tokens;

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;

  /// True right after sign-up, so the app shows its guided tour once.
  bool showTour = false;

  /// Set when the session ended because the server rejected it.
  bool expired = false;

  /// Set when a saved session couldn't be checked (e.g. offline at launch).
  ApiException? restoreError;

  /// Reopens the saved session, if any.
  Future<void> restore() async {
    restoreError = null;
    String? token;
    try {
      token = await _tokens.read();
    } catch (_) {
      token = null; // unreadable keystore entry: treat as signed out
    }
    if (token == null) return _set(AuthStatus.signedOut);
    api.token = token;
    try {
      final me = AppUser.fromJson(await api.get('/auth/me'));
      if (me.role != 'patient') return signOut();
      user = me;
      _set(AuthStatus.signedIn);
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 403) return signOut(expired: true);
      restoreError = e; // keep the token; the splash offers a retry
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async => _start(
    await api.post('/auth/login', {'email': email, 'password': password}),
  );

  Future<void> signUp(Map<String, Object?> fields) async {
    showTour = true;
    await _start(
      await api.post('/auth/register', {...fields, 'role': 'patient'}),
    );
  }

  Future<void> _start(dynamic res) async {
    final me = AppUser.fromJson(res['user']);
    if (me.role != 'patient') throw const NotPatientAccount();
    api.token = res['token'];
    await _tokens.write(res['token']);
    user = me;
    expired = false;
    _set(AuthStatus.signedIn);
  }

  /// Opens the app without an account (the login and sign-up screens are UI only for now).
  /// [newAccount] is true from sign-up, which shows the guided tour once.
  void enter({bool newAccount = false}) {
    expired = false;
    showTour = newAccount;
    _set(AuthStatus.signedIn);
  }

  /// Replace the cached profile after a change the server already saved.
  void updateUser(AppUser u) {
    user = u;
    notifyListeners();
  }

  Future<void> signOut({bool expired = false}) async {
    this.expired = expired;
    api.token = null;
    user = null;
    showTour = false;
    restoreError = null;
    _set(AuthStatus.signedOut);
    try {
      await _tokens.write(null);
    } catch (_) {}
  }

  void _set(AuthStatus s) {
    status = s;
    notifyListeners();
  }
}
