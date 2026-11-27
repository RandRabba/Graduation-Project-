import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'app_error.dart';
import 'models.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// The signed-in patient, backed by Firebase Authentication (who you are) and
/// the Firestore document `users/{uid}` (your profile).
///
/// Data layout and permissions: see `firebase/README.md` and
/// `firebase/firestore.rules` at the root of the repository.
class AuthSession extends ChangeNotifier {
  AuthSession({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _authOverride = auth,
      _dbOverride = firestore;

  // Resolved on first use so tests can build the session without Firebase.
  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _dbOverride;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;

  /// True right after sign-up, so the app shows its guided tour once.
  bool showTour = false;

  /// Set when the session ended because it was no longer valid.
  bool expired = false;

  /// Set when a saved session couldn't be checked (e.g. offline at launch).
  AppException? restoreError;

  /// Reopens the saved session, if any.
  Future<void> restore() async {
    restoreError = null;
    User? current;
    try {
      // Firebase restores its own saved session; the first event carries it.
      current = await _auth.authStateChanges().first;
    } catch (_) {
      current = null;
    }
    if (current == null) return _set(AuthStatus.signedOut);
    try {
      await _enter(current);
    } catch (e) {
      final failure = AppException.of(e);
      if (failure.key == 'err_not_patient') return signOut();
      restoreError = failure; // keep the session; the splash offers a retry
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final u = cred.user;
      if (u == null) throw const AppException('error_generic');
      await _enter(u);
    } catch (e) {
      throw AppException.of(e);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    DateTime? dateOfBirth,
    String? diabetesType,
    String? phone,
  }) async {
    final mail = email.trim().toLowerCase();
    final User u;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: mail,
        password: password,
      );
      final created = cred.user;
      if (created == null) throw const AppException('error_generic');
      u = created;
    } catch (e) {
      throw AppException.of(e);
    }
    try {
      await _db.collection('users').doc(u.uid).set(<String, Object?>{
        'role': 'patient',
        'email': mail,
        'fullName': fullName.trim(),
        'phone': phone ?? '',
        'diabetesType': diabetesType ?? '',
        'dateOfBirth': dateOfBirth == null ? '' : _dateText(dateOfBirth),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Do not leave an account without a profile behind.
      try {
        await u.delete();
      } catch (_) {
        await _auth.signOut();
      }
      throw AppException.of(e);
    }
    showTour = true;
    try {
      await _enter(u);
    } catch (e) {
      showTour = false;
      throw AppException.of(e);
    }
  }

  /// Loads (or, for an account that has none yet, creates) the profile and
  /// opens the app. Signs out and throws `err_not_patient` for any other role.
  Future<void> _enter(User u) async {
    final ref = _db.collection('users').doc(u.uid);
    var data = (await ref.get()).data();
    if (data == null) {
      final mail = (u.email ?? '').toLowerCase();
      data = <String, Object?>{
        'role': 'patient',
        'email': mail,
        'fullName': '',
        'phone': '',
        'diabetesType': '',
        'dateOfBirth': '',
      };
      await ref.set(<String, Object?>{
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else if (data['role'] != 'patient') {
      await _auth.signOut();
      throw const AppException('err_not_patient');
    }
    user = AppUser.fromDoc(u.uid, data);
    expired = false;
    _set(AuthStatus.signedIn);
  }

  /// Replace the cached profile and save it. The role and the email never
  /// change (the Firestore rules refuse it).
  void updateUser(AppUser u) {
    user = u;
    notifyListeners();
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    unawaited(
      _db
          .collection('users')
          .doc(uid)
          .update(<String, Object?>{
            'fullName': u.fullName,
            'phone': u.phone ?? '',
            'diabetesType': u.diabetesType ?? '',
            'dateOfBirth': u.dateOfBirth == null
                ? ''
                : _dateText(u.dateOfBirth!),
          })
          .catchError((Object e) => debugPrint('Could not save profile: $e')),
    );
  }

  Future<void> signOut({bool expired = false}) async {
    this.expired = expired;
    user = null;
    showTour = false;
    restoreError = null;
    _set(AuthStatus.signedOut);
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  void _set(AuthStatus s) {
    status = s;
    notifyListeners();
  }

  static String _dateText(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
