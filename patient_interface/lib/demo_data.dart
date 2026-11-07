/// Example instances of the repositories, filled with sample records so the
/// screens show something without the backend. Everything lives in memory and
/// resets when the app restarts.
library;

import 'common.dart';
import 'models.dart';
import 'repositories.dart';

Repositories demoRepositories() {
  final glucose = DemoGlucoseRepository();
  final entitlements = DemoEntitlementRepository();
  return Repositories(
    reminders: DemoReminderRepository(),
    glucose: glucose,
    alerts: glucose.alerts,
    doctorChat: DemoDoctorChatRepository(entitlements),
    entitlements: entitlements,
  );
}

class _Page<T> implements Paged<T> {
  _Page(this.items, this.nextBefore);
  @override
  final List<T> items;
  @override
  final DateTime? nextBefore;
}

/// Newest-first page of [all] (already sorted newest first) older than [before].
Paged<T> _page<T>(
  List<T> all,
  DateTime Function(T) at,
  int limit,
  DateTime? before,
) {
  final older = [
    for (final x in all)
      if (before == null || at(x).isBefore(before)) x,
  ];
  final items = older.take(limit).toList();
  return _Page(items, older.length > limit ? at(items.last) : null);
}

DateTime _ago({int days = 0, int hours = 0, int minutes = 0}) {
  final n = DateTime.now();
  final today = DateTime(n.year, n.month, n.day, n.hour, n.minute);
  return today.subtract(Duration(days: days, hours: hours, minutes: minutes));
}

DateTime _todayAt(int hour, [int minute = 0, int addDays = 0]) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + addDays, hour, minute);
}

class DemoReminderRepository implements ReminderRepository {
  var _n = 8;
  final _items = <Reminder>[
    // assigned by the doctor (sample data until the clinic side exists)
    Reminder(
      id: 'rem5',
      title: 'Check glucose 2 hours after dinner',
      description:
          'Log the reading so we can review your evening pattern at the next visit.',
      category: 'glucose',
      dueAt: _todayAt(21, 0),
      repeat: ReminderRepeat.daily,
      assignedBy: 'Dr. Sara Ali',
    ),
    Reminder(
      id: 'rem6',
      title: 'HbA1c blood test',
      description: 'Fasting not required. Bring the lab request form.',
      category: 'appointment',
      dueAt: _todayAt(9, 30, 3),
      assignedBy: 'Dr. Sara Ali',
    ),
    Reminder(
      id: 'rem7',
      title: '20-minute walk after lunch',
      description: 'A light walk helps lower after-meal glucose.',
      category: 'general',
      dueAt: _todayAt(14, 0, -1),
      assignedBy: 'Dr. Sara Ali',
      completed: true,
    ),
    Reminder(
      id: 'rem8',
      title: 'Refill test strips',
      category: 'general',
      dueAt: _todayAt(18, 0, -2),
      completed: true,
    ),
    Reminder(
      id: 'rem1',
      title: 'Check fasting glucose',
      description: 'Before breakfast, with the meter.',
      category: 'glucose',
      dueAt: _todayAt(7, 30, 1),
      repeat: ReminderRepeat.daily,
    ),
    Reminder(
      id: 'rem2',
      title: 'Lunch',
      description: 'Log carbs in the Meals tab.',
      category: 'meal',
      dueAt: _todayAt(13, 0, 1),
      repeat: ReminderRepeat.daily,
    ),
    Reminder(
      id: 'rem3',
      title: 'Appointment with Dr. Sara Ali',
      description: 'Bring your last HbA1c result.',
      category: 'appointment',
      dueAt: _todayAt(10, 0, 5),
    ),
    Reminder(
      id: 'rem4',
      title: 'Weekly weigh-in',
      category: 'general',
      dueAt: _todayAt(9, 0, 2),
      repeat: ReminderRepeat.weekly,
      enabled: false,
    ),
  ];

  @override
  Future<List<Reminder>> list() async =>
      [..._items]..sort((a, b) => a.dueAt.compareTo(b.dueAt));

  @override
  Future<Reminder> save(Reminder r) async {
    final saved = r.copyWith(id: r.id ?? 'rem${++_n}');
    _items
      ..removeWhere((x) => x.id == saved.id)
      ..add(saved);
    return saved;
  }

  @override
  Future<Reminder> setEnabled(String id, bool enabled) async {
    final i = _items.indexWhere((x) => x.id == id);
    return _items[i] = _items[i].copyWith(enabled: enabled);
  }

  @override
  Future<void> delete(String id) async => _items.removeWhere((x) => x.id == id);
}

class _AddResult implements GlucoseAddResult {
  _AddResult(this.created, this.duplicates, this.alerts);
  @override
  final List<GlucoseReading> created;
  @override
  final int duplicates;
  @override
  final List<AlertItem> alerts;
}

class DemoGlucoseRepository implements GlucoseRepository {
  DemoGlucoseRepository() {
    final samples = [
      (_ago(hours: 1), 128.0, 'dexcom', 'G7-4821', null),
      (_ago(hours: 3), 196.0, 'dexcom', 'G7-4821', 'After lunch'),
      (_ago(hours: 6), 104.0, 'meter', null, null),
      (_ago(hours: 9), 62.0, 'dexcom', 'G7-4821', 'Had juice'),
      (_ago(days: 1, hours: 2), 142.0, 'dexcom', 'G7-4821', null),
      (_ago(days: 1, hours: 5), 268.0, 'dexcom', 'G7-4821', 'Missed bolus'),
      (_ago(days: 1, hours: 8), 118.0, 'manual', null, null),
      (_ago(days: 1, hours: 12), 95.0, 'meter', null, 'Fasting'),
      (_ago(days: 2, hours: 1), 51.0, 'dexcom', 'G7-4821', 'Night low'),
      (_ago(days: 2, hours: 6), 156.0, 'manual', null, null),
      (_ago(days: 2, hours: 10), 110.0, 'meter', null, 'Fasting'),
      (_ago(days: 3, hours: 4), 188.0, 'dexcom', 'G7-4821', 'Pizza dinner'),
      (_ago(days: 3, hours: 9), 99.0, 'manual', null, null),
    ];
    for (final (at, value, source, sensor, note) in samples) {
      final r = GlucoseReading(
        id: 'g${++_n}',
        value: value,
        at: at,
        source: source,
        sensor: sensor,
        note: note,
      );
      _readings.add(r);
      alerts._fromReading(r, read: at.isBefore(_ago(hours: 12)));
    }
    alerts._add(
      'doctor_reminder',
      'Dr. Sara Ali assigned you a reminder: HbA1c blood test.',
      null,
      _ago(minutes: 40),
    );
    alerts._add(
      'emergency',
      'You sent an SOS to your caregiver.',
      null,
      _ago(days: 2, minutes: 50),
      read: true,
    );
  }

  final alerts = DemoAlertRepository();
  final _readings = <GlucoseReading>[];
  var _n = 0;

  @override
  Future<Paged<GlucoseReading>> history({
    int limit = 50,
    DateTime? before,
  }) async => _page(
    [..._readings]..sort((a, b) => b.at.compareTo(a.at)),
    (r) => r.at,
    limit,
    before,
  );

  @override
  Future<GlucoseAddResult> add(List<GlucoseReading> readings) async {
    final created = <GlucoseReading>[], raised = <AlertItem>[];
    var duplicates = 0;
    for (final r in readings) {
      // one reading per source and minute, like the backend's per-second rule
      if (_readings.any((x) => x.source == r.source && x.at == r.at)) {
        duplicates++;
        continue;
      }
      final saved = GlucoseReading(
        id: 'g${++_n}',
        value: r.value,
        at: r.at,
        source: r.source,
        sensor: r.sensor,
        note: r.note,
      );
      _readings.add(saved);
      created.add(saved);
      final alert = alerts._fromReading(saved);
      if (alert != null) raised.add(alert);
    }
    return _AddResult(created, duplicates, raised);
  }
}

class DemoAlertRepository implements AlertRepository {
  final _items = <AlertItem>[];
  var _n = 0;

  AlertItem? _fromReading(GlucoseReading r, {bool read = false}) {
    final v = r.value.round();
    final (type, message) = switch (GlucoseLevel.of(r.value)) {
      GlucoseLevel.veryLow => (
        'critical_low',
        'Very low glucose: $v mg/dL. Treat it now and follow your hypo plan.',
      ),
      GlucoseLevel.low => ('low', 'Low glucose: $v mg/dL.'),
      GlucoseLevel.high => ('high', 'High glucose: $v mg/dL.'),
      GlucoseLevel.veryHigh => (
        'critical_high',
        'Very high glucose: $v mg/dL. Check ketones if advised and contact your care team.',
      ),
      GlucoseLevel.inRange => ('', ''),
    };
    if (type.isEmpty) return null;
    return _add(
      type,
      message,
      r,
      r.at.add(const Duration(minutes: 1)),
      read: read,
    );
  }

  AlertItem _add(
    String type,
    String message,
    GlucoseReading? r,
    DateTime at, {
    bool read = false,
  }) {
    final a = AlertItem(
      id: 'a${++_n}',
      type: type,
      message: message,
      at: at,
      read: read,
      glucose: r?.value,
      readingAt: r?.at,
      caregiverNotified: type.startsWith('critical') || type == 'emergency',
    );
    _items.add(a);
    return a;
  }

  @override
  Future<Paged<AlertItem>> history({int limit = 50, DateTime? before}) async =>
      _page(
        [..._items]..sort((a, b) => b.at.compareTo(a.at)),
        (a) => a.at,
        limit,
        before,
      );

  @override
  Future<int> unreadCount() async => _items.where((a) => !a.read).length;

  @override
  Future<void> markRead(String id) async {
    final i = _items.indexWhere((a) => a.id == id);
    _items[i] = _items[i].copyWith(read: true);
  }

  @override
  Future<void> markAllRead() async {
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(read: true);
    }
  }
}

class _PaymentRequired implements PaymentRequired {
  const _PaymentRequired(this.feature);
  @override
  final PaidFeature feature;
}

/// Starts without doctor chat; "buying" it unlocks it at once.
class DemoEntitlementRepository implements EntitlementRepository {
  final _owned = <PaidFeature>{};

  @override
  Future<bool> hasAccess(PaidFeature feature) async => _owned.contains(feature);

  @override
  Future<bool> purchase(PaidFeature feature) async {
    _owned.add(feature);
    return true;
  }

  @override
  Future<void> restore() async {}
}

class DemoDoctorChatRepository implements DoctorChatRepository {
  DemoDoctorChatRepository(this._entitlements);
  final EntitlementRepository _entitlements;

  static const _doctor = Person(
    id: 'd1',
    fullName: 'Dr. Sara Ali',
    email: 'sara@clinic.org',
    specialty: 'Endocrinology',
  );

  var _n = 0;
  late final _messages = [
    _msg(
      'patient',
      'Hello doctor, I had a low of 51 last night.',
      _ago(days: 2, hours: 1),
    ),
    _msg(
      'doctor',
      'Thanks for telling me. Did you treat it with 15 g of fast carbs?',
      _ago(days: 2),
    ),
    _msg(
      'patient',
      'Yes, juice. It came back to 110 by the morning.',
      _ago(days: 1, hours: 23),
    ),
    _msg(
      'doctor',
      'Good. Let’s lower your evening basal by 2 units and check again in a week.',
      _ago(days: 1, hours: 22),
    ),
    _msg(
      'patient',
      'OK, I will. My readings are a bit high after lunch too.',
      _ago(hours: 2),
    ),
  ];

  ChatMessage _msg(String role, String text, DateTime at) => ChatMessage(
    id: 'm${++_n}',
    senderRole: role,
    text: text,
    at: at,
    createdAt: utcIso(at),
  );

  Future<void> _check() async {
    if (!await _entitlements.hasAccess(PaidFeature.doctorChat)) {
      throw const _PaymentRequired(PaidFeature.doctorChat);
    }
  }

  @override
  Future<Person> doctor() async => _doctor;

  @override
  Future<Paged<ChatMessage>> history({int limit = 50, DateTime? before}) async {
    await _check();
    return _page(_messages.reversed.toList(), (m) => m.at, limit, before);
  }

  @override
  Future<List<ChatMessage>> since(DateTime after) async {
    await _check();
    return [
      for (final m in _messages)
        if (m.at.isAfter(after)) m,
    ];
  }

  @override
  Future<ChatMessage> send(String text) async {
    await _check();
    final m = _msg('patient', text, DateTime.now());
    _messages.add(m);
    return m;
  }

  @override
  Future<bool> hasUnread() async => false;

  @override
  Future<void> markRead() async {}
}
