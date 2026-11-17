/// Records returned by the DMS backend. Server times are UTC; these hold local time.
library;

DateTime _time(Object? v) => DateTime.parse(v as String).toLocal();
DateTime? _timeOrNull(Object? v) => v == null ? null : _time(v);
double? _num(Object? v) => (v as num?)?.toDouble();

/// Server timestamp format for query cursors and request bodies.
String utcIso(DateTime t) => t.toUtc().toIso8601String();

class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    required this.email,
    required this.fullName,
    this.dateOfBirth,
    this.diabetesType,
    this.phone,
    this.doctorId,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'],
    role: j['role'],
    email: j['email'],
    fullName: j['full_name'],
    dateOfBirth: j['date_of_birth'] == null
        ? null
        : DateTime.parse(j['date_of_birth']),
    diabetesType: j['diabetes_type'],
    phone: j['phone'],
    doctorId: j['doctor_id'],
  );

  final String id, role, email, fullName;
  final DateTime? dateOfBirth;
  final String? diabetesType, phone, doctorId;
}

/// Another account as others may see it (doctor or caregiver).
class Person {
  const Person({
    required this.id,
    required this.fullName,
    required this.email,
    this.specialty,
  });

  factory Person.fromJson(Map<String, dynamic> j) => Person(
    id: j['id'],
    fullName: j['full_name'],
    email: j['email'],
    specialty: j['specialty'],
  );

  final String id, fullName, email;
  final String? specialty;
}

class GlucoseReading {
  const GlucoseReading({
    required this.id,
    required this.value,
    required this.at,
    required this.source,
    this.sensor,
    this.note,
  });

  factory GlucoseReading.fromJson(Map<String, dynamic> j) => GlucoseReading(
    id: j['id'],
    value: _num(j['value'])!,
    at: _time(j['timestamp']),
    source: j['source'] ?? 'manual',
    sensor: j['sensor'],
    note: j['note'],
  );

  final String id, source;

  /// mg/dL
  final double value;
  final DateTime at;
  final String? sensor, note;
}

class AlertItem {
  const AlertItem({
    required this.id,
    required this.type,
    required this.message,
    required this.at,
    required this.read,
    this.glucose,
    this.readingAt,
    this.caregiverNotified,
  });

  factory AlertItem.fromJson(Map<String, dynamic> j) => AlertItem(
    id: j['id'],
    type: j['type'],
    message: j['message'] ?? '',
    at: _time(j['created_at']),
    read: j['read'] == true,
    glucose: _num(j['glucose']),
    readingAt: _timeOrNull(j['reading_at']),
    caregiverNotified: j['caregiver_notified'],
  );

  final String id, type, message;
  final DateTime at;
  final bool read;
  final double? glucose;
  final DateTime? readingAt;
  final bool? caregiverNotified;

  AlertItem copyWith({bool? read}) => AlertItem(
    id: id,
    type: type,
    message: message,
    at: at,
    read: read ?? this.read,
    glucose: glucose,
    readingAt: readingAt,
    caregiverNotified: caregiverNotified,
  );
}

enum ReminderRepeat { none, daily, weekly }

class Reminder {
  const Reminder({
    this.id,
    required this.title,
    this.description = '',
    this.category = 'general',
    required this.dueAt,
    this.repeat = ReminderRepeat.none,
    this.enabled = true,
    this.assignedBy,
    this.completed = false,
  });

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
    id: j['id'],
    title: j['title'],
    description: j['description'] ?? '',
    category: j['category'] ?? 'general',
    dueAt: _time(j['due_at']),
    repeat: ReminderRepeat.values.byName(j['repeat'] ?? 'none'),
    enabled: j['enabled'] != false,
    assignedBy: j['assigned_by_name'],
    completed: j['completed'] == true,
  );

  /// Null until saved.
  final String? id;
  final String title, description;

  /// glucose, meal, appointment or general
  final String category;
  final DateTime dueAt;
  final ReminderRepeat repeat;
  final bool enabled;

  /// Name of the doctor who assigned it; null for the patient's own reminders.
  final String? assignedBy;

  /// Marked done by the patient.
  final bool completed;

  bool get fromDoctor => assignedBy != null;

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'category': category,
    'due_at': utcIso(dueAt),
    'repeat': repeat.name,
    'enabled': enabled,
  };

  Reminder copyWith({String? id, bool? enabled, bool? completed}) => Reminder(
    id: id ?? this.id,
    title: title,
    description: description,
    category: category,
    dueAt: dueAt,
    repeat: repeat,
    enabled: enabled ?? this.enabled,
    assignedBy: assignedBy,
    completed: completed ?? this.completed,
  );

  /// When it next fires at or after [now], or null if a one-off is already past.
  /// Steps by calendar day so the wall-clock time survives daylight-saving changes.
  DateTime? nextAfter(DateTime now) {
    final d = dueAt;
    if (!d.isBefore(now)) return d;
    if (repeat == ReminderRepeat.none) return null;
    final step = repeat == ReminderRepeat.daily ? 1 : 7;
    final days = now.difference(d).inDays ~/ step * step;
    var n = days;
    DateTime at() => DateTime(d.year, d.month, d.day + n, d.hour, d.minute);
    while (at().isBefore(now)) {
      n += step;
    }
    return at();
  }
}

class Conversation {
  const Conversation({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.unread,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
    id: j['id'],
    doctorId: j['doctor_id'],
    doctorName: j['doctor_name'] ?? '',
    unread: j['unread'] == true,
  );

  final String id, doctorId, doctorName;
  final bool unread;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderRole,
    required this.text,
    required this.at,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: j['id'],
    senderRole: j['sender_role'],
    text: j['text'],
    at: _time(j['created_at']),
    createdAt: j['created_at'],
  );

  final String id, senderRole, text;
  final DateTime at;

  /// Raw server timestamp, used as the polling cursor.
  final String createdAt;

  bool get fromPatient => senderRole == 'patient';
}

/// The patient's caregiver invitation or active link.
class CaregiverLink {
  const CaregiverLink({
    required this.status,
    required this.shareGlucose,
    required this.caregiver,
  });

  factory CaregiverLink.fromJson(Map<String, dynamic> j) => CaregiverLink(
    status: j['status'],
    shareGlucose: j['share_glucose'] == true,
    caregiver: j['caregiver'] == null ? null : Person.fromJson(j['caregiver']),
  );

  /// pending, active or declined
  final String status;
  final bool shareGlucose;
  final Person? caregiver;
}
