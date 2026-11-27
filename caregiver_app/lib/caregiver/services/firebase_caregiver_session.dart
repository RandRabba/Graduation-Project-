import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'caregiver_auth.dart';
import 'glucose_math.dart';

/// Where the signed-in caregiver stands with a patient.
enum LinkPhase { signedOut, loading, linked, noPatient, error }

/// The Firebase side of the Caregiver module: who is signed in, and which
/// patient added them.
///
/// Data layout and permissions: see `firebase/README.md` and
/// `firebase/firestore.rules` at the root of the repository.
///
/// A caregiver registers with the email the patient added. The patient's
/// invitation is the document `links/{email}`; registering only succeeds when
/// it exists (the Firestore rules refuse the profile otherwise), and the app
/// then marks it `active`. If the patient deletes the document, the live
/// listener below moves the app to the "no linked patient" state.
class FirebaseCaregiverSession extends ChangeNotifier implements CaregiverAuth {
  FirebaseCaregiverSession({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  LinkPhase phase = LinkPhase.signedOut;
  CaregiverProfile? profile;
  Patient? patient;

  /// The patient's uid, and whether they share glucose history.
  String? patientUid;
  bool shareGlucose = false;

  /// The patient's readings, newest first. Empty while the patient does not
  /// share glucose (the Firestore rules refuse the read in that case).
  List<GlucoseReading> readings = const <GlucoseReading>[];

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _linkSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _readingsSub;
  String? _watchedReadingsPid;
  String? _loadedPatientUid;
  bool _disposed = false;

  // ---- CaregiverAuth -------------------------------------------------------

  @override
  Future<bool> restore() async {
    // The first event is the session Firebase kept from the last run, or null.
    final User? user = await _auth.authStateChanges().first;
    if (user == null) return false;
    try {
      return await _enter(user) == SignInOutcome.caregiver;
    } on AuthFailure {
      return false;
    } on FirebaseException {
      return false;
    }
  }

  @override
  Future<SignInOutcome> signIn({required String email, required String password}) async {
    try {
      final UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final User? user = cred.user;
      if (user == null) throw const AuthFailure('errGeneric');
      return await _enter(user);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_authKey(e.code));
    } on FirebaseException catch (e) {
      throw AuthFailure(_dbKey(e.code));
    }
  }

  @override
  Future<void> register({required String email, required String password}) async {
    final String mail = email.trim().toLowerCase();
    final UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(email: mail, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_authKey(e.code));
    }
    final User? user = cred.user;
    if (user == null) throw const AuthFailure('errGeneric');

    try {
      // The rules accept a caregiver profile only when a patient added this
      // email, so an uninvited email stops here.
      await _db.collection('users').doc(user.uid).set(<String, Object?>{
        'role': 'caregiver',
        'email': mail,
        'fullName': '',
        'phone': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      // Do not leave an account behind for an email nobody invited.
      try {
        await user.delete();
      } catch (_) {
        await _auth.signOut();
      }
      throw AuthFailure(e.code == 'permission-denied' ? 'errNoInvite' : _dbKey(e.code));
    }

    try {
      await _enter(user);
    } on FirebaseException catch (e) {
      throw AuthFailure(_dbKey(e.code));
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      // Not reported, so the form cannot be used to find out who has an account.
      if (e.code == 'user-not-found') return;
      throw AuthFailure(_authKey(e.code));
    }
  }

  @override
  Future<void> changePassword({required String current, required String next}) async {
    final User? user = _auth.currentUser;
    final String? mail = user?.email;
    if (user == null || mail == null) throw const AuthFailure('errGeneric');
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: mail, password: current),
      );
      await user.updatePassword(next);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw const AuthFailure('errCurPw');
      }
      throw AuthFailure(_authKey(e.code));
    }
  }

  @override
  Future<void> signOut() => _clear();

  // ---- Used by FirebaseCaregiverRepository ----------------------------------

  /// Loads everything again (the "Try again" / "Check again" buttons).
  Future<void> reload() async {
    final User? user = _auth.currentUser;
    if (user == null) return;
    _loadedPatientUid = null;
    try {
      await _enter(user);
    } on AuthFailure {
      // The phase already tells the screens what happened.
    } on FirebaseException {
      // Same: the phase is "error".
    }
  }

  /// The caregiver leaves the patient. The live listener then reports "no
  /// linked patient".
  Future<void> disconnect() async {
    final String? mail = _auth.currentUser?.email?.toLowerCase();
    if (mail == null) return;
    try {
      await _db.collection('links').doc(mail).delete();
    } on FirebaseException {
      _setPhase(LinkPhase.error);
    }
  }

  Future<void> saveProfile({required String name, required String phone}) async {
    final User? user = _auth.currentUser;
    if (user == null) return;
    try {
      await _db.collection('users').doc(user.uid).update(<String, Object?>{
        'fullName': name.trim(),
        'phone': phone.trim(),
      });
      profile = _profileFrom(
        (user.email ?? '').toLowerCase(),
        <String, dynamic>{'fullName': name, 'phone': phone},
      );
      _notify();
    } on FirebaseException {
      // The screen already shows the edit; it is saved again on the next edit.
    }
  }

  // ---- Internals ---------------------------------------------------------------

  /// Loads the caregiver's profile, checks the role and starts listening to
  /// the invitation.
  Future<SignInOutcome> _enter(User user) async {
    _setPhase(LinkPhase.loading);
    final String email = (user.email ?? '').toLowerCase();
    try {
      final DocumentReference<Map<String, dynamic>> ref = _db.collection('users').doc(user.uid);
      final DocumentSnapshot<Map<String, dynamic>> snap = await ref.get();
      Map<String, dynamic>? data = snap.data();
      if (data == null) {
        // An account without a profile is only valid for an invited caregiver
        // (a registration that stopped half way).
        data = <String, dynamic>{
          'role': 'caregiver',
          'email': email,
          'fullName': '',
          'phone': '',
          'createdAt': FieldValue.serverTimestamp(),
        };
        try {
          await ref.set(data);
        } on FirebaseException catch (e) {
          if (e.code != 'permission-denied') rethrow;
          await _clear();
          throw const AuthFailure('errNoInvite');
        }
      }
      if (data['role'] != 'caregiver') {
        await _clear();
        return SignInOutcome.patientAccount;
      }
      profile = _profileFrom(email, data);
      await _watchLink(email, user.uid);
      return SignInOutcome.caregiver;
    } on FirebaseException {
      _setPhase(LinkPhase.error);
      rethrow;
    }
  }

  /// Listens to `links/{email}`. Completes after the first answer, so a
  /// sign in returns when the link state is known.
  Future<void> _watchLink(String email, String uid) async {
    await _linkSub?.cancel();
    final Completer<void> first = Completer<void>();
    _linkSub = _db.collection('links').doc(email).snapshots().listen(
      (DocumentSnapshot<Map<String, dynamic>> snap) async {
        await _onLink(snap, uid);
        if (!first.isCompleted) first.complete();
      },
      onError: (Object _) {
        _setPhase(LinkPhase.error);
        if (!first.isCompleted) first.complete();
      },
    );
    await first.future;
  }

  Future<void> _onLink(DocumentSnapshot<Map<String, dynamic>> snap, String uid) async {
    try {
      final Map<String, dynamic>? link = snap.data();
      if (link == null) {
        patient = null;
        patientUid = null;
        shareGlucose = false;
        _loadedPatientUid = null;
        _watchReadings();
        _setPhase(LinkPhase.noPatient);
        return;
      }
      if (link['status'] == 'pending') {
        // First time with this invitation: record which account owns the
        // email. There is no accept step. The update brings the next snapshot.
        await snap.reference.update(<String, Object?>{
          'status': 'active',
          'caregiverUid': uid,
          'claimedAt': FieldValue.serverTimestamp(),
        });
        return;
      }
      final String pid = '${link['patientUid'] ?? ''}';
      if (pid.isEmpty) {
        _setPhase(LinkPhase.noPatient);
        return;
      }
      if (_loadedPatientUid != pid) {
        final DocumentSnapshot<Map<String, dynamic>> p =
            await _db.collection('users').doc(pid).get();
        patient = _patientFrom(p.data() ?? const <String, dynamic>{});
        _loadedPatientUid = pid;
      }
      patientUid = pid;
      shareGlucose = link['shareGlucose'] == true;
      _watchReadings();
      _setPhase(LinkPhase.linked);
    } on FirebaseException {
      _setPhase(LinkPhase.error);
    }
  }

  /// Listens to the patient's readings while the patient shares glucose, and
  /// stops when the link ends or sharing is switched off. Keeps the newest 500.
  void _watchReadings() {
    final String? pid = shareGlucose ? patientUid : null;
    if (pid == _watchedReadingsPid) return;
    _readingsSub?.cancel();
    _readingsSub = null;
    _watchedReadingsPid = pid;
    readings = const <GlucoseReading>[];
    if (pid == null) return;
    _readingsSub = _db
        .collection('patients')
        .doc(pid)
        .collection('readings')
        .orderBy('at', descending: true)
        .limit(500)
        .snapshots()
        .listen(
      (QuerySnapshot<Map<String, dynamic>> snap) {
        final List<GlucoseReading> list = <GlucoseReading>[];
        for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) {
          final GlucoseReading? r = _readingFrom(d.id, d.data());
          if (r != null) list.add(r);
        }
        readings = list;
        _notify();
      },
      onError: (Object _) {
        readings = const <GlucoseReading>[];
        _notify();
      },
    );
  }

  /// A reading document written by the patient app; null when it is malformed.
  static GlucoseReading? _readingFrom(String id, Map<String, dynamic> d) {
    final Object? value = d['value'];
    final Object? at = d['at'];
    if (value is! num || at is! Timestamp) return null;
    final Object? source = d['source'];
    final Object? timing = d['timing'];
    return caregiverReading(
      id: id,
      value: value.toDouble(),
      time: at.toDate(),
      source: source is String ? source : 'manual',
      timing: timing is String ? timing : null,
    );
  }

  Future<void> _clear() async {
    await _linkSub?.cancel();
    _linkSub = null;
    profile = null;
    patient = null;
    patientUid = null;
    shareGlucose = false;
    _loadedPatientUid = null;
    _watchReadings();
    await _auth.signOut();
    _setPhase(LinkPhase.signedOut);
  }

  void _setPhase(LinkPhase p) {
    phase = p;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _linkSub?.cancel();
    _readingsSub?.cancel();
    super.dispose();
  }

  // ---- Mapping --------------------------------------------------------------------

  static const EmergencyContact _noContact = EmergencyContact(
    name: LocalizedText('', ''),
    relation: LocalizedText('', ''),
    phone: '',
    initials: LocalizedText('', ''),
  );

  static LocalizedText _t(String v) => LocalizedText(v, v);

  static String _str(Object? v) => v is String ? v.trim() : '';

  /// The patient app stores a code such as `type1`; documents written by hand
  /// may hold plain text, which is shown as it is.
  static LocalizedText _diabetes(String v) => switch (v) {
    'type1' => const LocalizedText('Type 1', 'النوع الأول'),
    'type2' => const LocalizedText('Type 2', 'النوع الثاني'),
    'gestational' => const LocalizedText('Gestational', 'سكري الحمل'),
    'prediabetes' => const LocalizedText('Prediabetes', 'مقدمات السكري'),
    'other' => const LocalizedText('Other', 'آخر'),
    _ => _t(v),
  };

  static CaregiverProfile _profileFrom(String email, Map<String, dynamic> d) {
    final String saved = _str(d['fullName']);
    final String name = saved.isEmpty ? _nameFromEmail(email) : saved;
    return CaregiverProfile(
      name: _t(name),
      initials: _t(_initials(name)),
      email: email,
      phone: _str(d['phone']),
    );
  }

  static Patient _patientFrom(Map<String, dynamic> d) {
    final String saved = _str(d['fullName']);
    final String name = saved.isEmpty ? _nameFromEmail(_str(d['email'])) : saved;
    return Patient(
      name: _t(name),
      initials: _t(_initials(name)),
      diabetesType: _diabetes(_str(d['diabetesType'])),
      doctorName: _t(''),
      clinic: _t(''),
      emergencyContact: _noContact,
      status: PatientStatus.normal,
    );
  }

  /// First character of a non-empty word (safe for non-Latin scripts).
  static String _firstChar(String word) => String.fromCharCode(word.runes.first);

  static String _capitalize(String word) {
    final String f = _firstChar(word);
    return f.toUpperCase() + word.substring(f.length);
  }

  /// `nour.haddad@example.com` -> `Nour Haddad`, until the user sets a name.
  static String _nameFromEmail(String email) {
    final String local = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ').trim();
    if (local.isEmpty) return '';
    return local.split(' ').where((String w) => w.isNotEmpty).map(_capitalize).join(' ');
  }

  static String _initials(String name) {
    final List<String> words = name.split(' ').where((String w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    final String second = words.length > 1 ? _firstChar(words[1]) : '';
    return (_firstChar(words[0]) + second).toUpperCase();
  }

  /// Firebase Auth error code -> key of the string table.
  static String _authKey(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return 'errCred';
      case 'too-many-requests':
        return 'errMany';
      case 'network-request-failed':
        return 'errNet';
      case 'email-already-in-use':
        return 'errUsed';
      case 'weak-password':
        return 'errLen';
      default:
        return 'errGeneric';
    }
  }

  /// Firestore error code -> key of the string table.
  static String _dbKey(String code) {
    switch (code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return 'errNet';
      default:
        return 'errGeneric';
    }
  }
}
