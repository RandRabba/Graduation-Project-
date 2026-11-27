import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'app_error.dart';
import 'auth.dart';
import 'meal_analysis.dart';
import 'models.dart';
import 'notifications.dart';
import 'repositories.dart';

/// App-wide preferences. Kept in memory only — add shared_preferences to remember them between launches.
class AppSettings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('en');

  ThemeMode get themeMode => _themeMode;
  set themeMode(ThemeMode m) {
    if (m == _themeMode) return;
    _themeMode = m;
    notifyListeners();
  }

  Locale get locale => _locale;
  set locale(Locale l) {
    if (l == _locale) return;
    _locale = l;
    notifyListeners();
  }
}

/// The paired sensor, shared by the Sensor, Summary and Profile tabs.
class SensorSession extends ChangeNotifier {
  static const warmup = Duration(minutes: 30);

  DateTime? _startedAt;
  String? _code;
  Timer? _ticker;

  /// Today's readings from the backend (see [loadToday]). Offset(hourOfDay 0-24, glucose in mg/dL).
  final List<Offset> _readings = [];

  /// Replaces [readings] with today's readings stored for the signed-in patient.
  Future<void> loadToday(GlucoseRepository repo) async {
    final n = DateTime.now();
    final start = DateTime(n.year, n.month, n.day);
    final today = <GlucoseReading>[];
    DateTime? before;
    do {
      final page = await repo.history(limit: 200, before: before);
      final items = page.items;
      today.addAll(items.where((r) => !r.at.isBefore(start)));
      before = page.nextBefore;
      if (items.isEmpty || items.last.at.isBefore(start)) break;
    } while (before != null);
    _readings
      ..clear()
      ..addAll([
        for (final r in today.reversed)
          Offset(r.at.hour + r.at.minute / 60, r.value),
      ]);
    notifyListeners();
  }

  /// Shows a reading the patient just saved without waiting for the next reload.
  void addLocal(DateTime at, double mgdl) {
    final n = DateTime.now();
    if (at.year != n.year || at.month != n.month || at.day != n.day) return;
    _readings
      ..add(Offset(at.hour + at.minute / 60, mgdl))
      ..sort((a, b) => a.dx.compareTo(b.dx));
    notifyListeners();
  }

  List<Offset> get readings => List.unmodifiable(_readings);
  Offset? get latest => _readings.isEmpty ? null : _readings.last;

  DateTime? get startedAt => _startedAt;
  String? get code => _code;
  bool get paired => _startedAt != null;

  Duration get remaining {
    final s = _startedAt;
    if (s == null) return warmup;
    final left = warmup - DateTime.now().difference(s);
    return left.isNegative ? Duration.zero : left;
  }

  bool get warming => paired && remaining > Duration.zero;
  double get warmupProgress => 1 - remaining.inSeconds / warmup.inSeconds;

  void pair(String code) {
    // TODO: hand `code` to your real Dexcom pairing logic (BLE / API).
    _code = code;
    _startedAt = DateTime.now();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!warming) t.cancel();
      notifyListeners();
    });
    notifyListeners();
  }

  void remove() {
    _ticker?.cancel();
    _startedAt = null;
    _code = null;
    _readings.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// Meals the user has analyzed, newest first. In memory only, like [AppSettings].
class MealLog extends ChangeNotifier {
  final List<MealEntry> _entries = [];

  List<MealEntry> get entries => List.unmodifiable(_entries.reversed);

  List<MealEntry> get today {
    final n = DateTime.now();
    return entries
        .where(
          (e) =>
              e.at.year == n.year && e.at.month == n.month && e.at.day == n.day,
        )
        .toList();
  }

  void add(MealEntry e) {
    _entries.add(e);
    notifyListeners();
  }

  void remove(MealEntry e) {
    _entries.remove(e);
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}

/// Unread alert count for badges. Refreshed after anything that can create or read alerts.
class AlertInbox extends ChangeNotifier {
  AlertInbox(this._alerts);
  final AlertRepository _alerts;
  int _unread = 0;

  int get unread => _unread;
  set unread(int n) {
    if (n == _unread) return;
    _unread = n;
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      unread = await _alerts.unreadCount();
    } catch (_) {
      // the badge is a hint; the Alerts screen shows the real error
    }
  }
}

/// The patient's reminders, mirrored onto the device's notification schedule.
class ReminderList extends ChangeNotifier {
  ReminderList(this._repo, this.scheduler);
  final ReminderRepository _repo;
  final ReminderScheduler scheduler;

  List<Reminder> _items = [];
  bool _loaded = false;

  List<Reminder> get items => List.unmodifiable(_items);
  bool get loaded => _loaded;

  Future<void> load() async {
    _items = await _repo.list();
    _loaded = true;
    notifyListeners();
    await _sync();
  }

  /// Creates or updates [r] and returns the saved copy.
  Future<Reminder> save(Reminder r) async {
    final saved = await _repo.save(r);
    _replace(saved);
    return saved;
  }

  Future<void> toggle(Reminder r, bool enabled) async =>
      _replace(await _repo.setEnabled(r.id!, enabled));

  /// Marks [r] done (or not done again). Done reminders stop ringing.
  Future<void> setCompleted(Reminder r, bool completed) async =>
      _replace(await _repo.save(r.copyWith(completed: completed)));

  Future<void> remove(Reminder r) async {
    await _repo.delete(r.id!);
    _items = [..._items.where((x) => x.id != r.id)];
    notifyListeners();
    await _sync();
  }

  /// Forget everything on sign-out, including scheduled notifications.
  Future<void> clear() async {
    _items = [];
    _loaded = false;
    notifyListeners();
    try {
      await scheduler.cancelAll();
    } catch (e) {
      debugPrint('Could not cancel reminders: $e');
    }
  }

  void _replace(Reminder saved) {
    _items = [..._items.where((x) => x.id != saved.id), saved]
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    notifyListeners();
    _sync();
  }

  Future<void> _sync() async {
    try {
      await scheduler.sync(_items);
    } catch (e) {
      // saving must not fail because the OS refused a notification
      debugPrint('Could not schedule reminders: $e');
    }
  }
}

/// The caregiver the patient added by email, kept in step with Firestore.
///
/// The invitation is the document `links/{caregiverEmail}`. The caregiver
/// registers in the Caregiver app with that email and the document becomes
/// `active`. Deleting it ends the caregiver's access at once.
class CaregiverAssignment extends ChangeNotifier {
  CaregiverAssignment({FirebaseFirestore? firestore})
    : _dbOverride = firestore;

  // Resolved on first use so tests can build it without Firebase.
  final FirebaseFirestore? _dbOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String? _uid;
  String? _email;
  String? _status;
  bool _shareGlucose = true;

  /// The caregiver's email, or null when none was added.
  String? get email => _email;

  /// `pending` (they have not registered yet) or `active`; null without a caregiver.
  String? get status => _status;
  bool get active => _status == 'active';

  /// Whether the caregiver may read the glucose history.
  bool get shareGlucose => _shareGlucose;

  /// Starts following this patient's link. Call when the patient signs in.
  void bind(String uid) {
    if (_uid == uid) return;
    unbind();
    _uid = uid;
    _sub = _db
        .collection('links')
        .where('patientUid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .listen(
          _onSnapshot,
          onError: (Object e) => debugPrint('Caregiver link: $e'),
        );
  }

  /// Stops following and forgets the link locally. It does not delete it.
  void unbind() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
    if (_email != null || _status != null) {
      _email = null;
      _status = null;
      notifyListeners();
    }
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> s) {
    if (s.docs.isEmpty) {
      _email = null;
      _status = null;
    } else {
      final d = s.docs.first;
      final data = d.data();
      _email = d.id;
      _status = data['status'] == 'active' ? 'active' : 'pending';
      _shareGlucose = data['shareGlucose'] != false;
    }
    notifyListeners();
  }

  /// Adds [email] as the caregiver, replacing the current one. One caregiver
  /// email follows one patient: if another patient already added it, this
  /// throws `err_link_taken`.
  Future<void> assign(String email) async {
    final uid = _uid;
    if (uid == null) throw const AppException('error_generic');
    final mail = email.trim().toLowerCase();
    if (mail == _email) return;
    final links = _db.collection('links');
    final batch = _db.batch();
    final old = _email;
    if (old != null) batch.delete(links.doc(old));
    batch.set(links.doc(mail), <String, Object?>{
      'patientUid': uid,
      'caregiverEmail': mail,
      'status': 'pending',
      'shareGlucose': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      throw e.code == 'permission-denied'
          ? const AppException('err_link_taken')
          : AppException.of(e);
    }
  }

  /// Removes the caregiver. They lose access immediately.
  Future<void> remove() async {
    final mail = _email;
    if (mail == null) return;
    try {
      await _db.collection('links').doc(mail).delete();
    } on FirebaseException catch (e) {
      throw AppException.of(e);
    }
  }

  /// Sends an SOS notification for the caregiver. Returns whether a caregiver
  /// who has registered will see it (false: none added, or not registered yet).
  Future<bool> sendSos({required String patientName, String? message}) async {
    final uid = _uid;
    final mail = _email;
    if (uid == null || mail == null) return false;
    try {
      await _db.collection('caregiverNotifications').add(<String, Object?>{
        'patientUid': uid,
        'patientName': patientName,
        'caregiverEmail': mail,
        'kind': 'sos',
        'message': message ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } on FirebaseException catch (e) {
      throw AppException.of(e);
    }
    return active;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Hands a shared notifier down the tree and rebuilds dependents when it changes.
class AppScope<T extends Listenable> extends InheritedNotifier<T> {
  const AppScope({super.key, required T super.notifier, required super.child});

  /// Use in build methods (rebuilds on change).
  static T of<T extends Listenable>(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope<T>>()!.notifier!;

  /// Use in callbacks (no rebuild dependency).
  static T read<T extends Listenable>(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope<T>>()!.notifier!;
}

extension AppStateX on BuildContext {
  AppSettings get settings => AppScope.of<AppSettings>(this);
  SensorSession get sensor => AppScope.of<SensorSession>(this);
  MealLog get meals => AppScope.of<MealLog>(this);
  AuthSession get auth => AppScope.of<AuthSession>(this);
  AlertInbox get inbox => AppScope.of<AlertInbox>(this);
  ReminderList get reminders => AppScope.of<ReminderList>(this);
  CaregiverAssignment get caregiver => AppScope.of<CaregiverAssignment>(this);
}
