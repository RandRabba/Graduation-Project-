/// Contracts for the reminders, glucose record, alert history and doctor chat features.
/// The app uses the example instances in demo_data.dart until real ones exist.
library;

import 'package:flutter/widgets.dart';
import 'models.dart';

/// One page of a newest-first list. Pass [nextBefore] back to load older items.
abstract class Paged<T> {
  List<T> get items;

  /// Null when there are no older items.
  DateTime? get nextBefore;
}

/// The patient's reminders.
abstract class ReminderRepository {
  /// Every reminder, soonest due first.
  Future<List<Reminder>> list();

  /// Creates [r] when it has no id, otherwise replaces it. Returns the saved copy.
  Future<Reminder> save(Reminder r);

  Future<Reminder> setEnabled(String id, bool enabled);

  Future<void> delete(String id);
}

/// Result of adding readings; re-sending a reading already stored counts as a duplicate.
abstract class GlucoseAddResult {
  List<GlucoseReading> get created;
  int get duplicates;

  /// Alerts raised by the new readings.
  List<AlertItem> get alerts;
}

/// The patient's stored glucose readings.
abstract class GlucoseRepository {
  /// Newest first, readings taken before [before] when given.
  Future<Paged<GlucoseReading>> history({int limit = 50, DateTime? before});

  Future<GlucoseAddResult> add(List<GlucoseReading> readings);
}

/// The signed-in user's alert history.
abstract class AlertRepository {
  /// Newest first, alerts created before [before] when given.
  Future<Paged<AlertItem>> history({int limit = 50, DateTime? before});

  Future<int> unreadCount();

  Future<void> markRead(String id);

  Future<void> markAllRead();
}

/// Paid features the patient can unlock.
enum PaidFeature { doctorChat }

/// Whether the patient has paid for a feature.
abstract class EntitlementRepository {
  Future<bool> hasAccess(PaidFeature feature);

  /// Starts the purchase flow. Returns true once access is granted.
  Future<bool> purchase(PaidFeature feature);

  /// Re-applies purchases made on another device or before a reinstall.
  Future<void> restore();
}

/// Thrown when a paid feature is used without access.
abstract class PaymentRequired implements Exception {
  PaidFeature get feature;
}

/// Chat with the clinic's single doctor. A paid feature: every call throws
/// [PaymentRequired] unless [EntitlementRepository.hasAccess] is true for
/// [PaidFeature.doctorChat].
abstract class DoctorChatRepository {
  /// The one doctor every patient talks to.
  Future<Person> doctor();

  /// Newest first, messages sent before [before] when given.
  Future<Paged<ChatMessage>> history({int limit = 50, DateTime? before});

  /// Messages that arrived after [after], oldest first, for polling.
  Future<List<ChatMessage>> since(DateTime after);

  Future<ChatMessage> send(String text);

  Future<bool> hasUnread();

  Future<void> markRead();
}

/// Every repository the screens use, handed down the widget tree.
class Repositories {
  const Repositories({
    required this.reminders,
    required this.glucose,
    required this.alerts,
    required this.doctorChat,
    required this.entitlements,
  });

  final ReminderRepository reminders;
  final GlucoseRepository glucose;
  final AlertRepository alerts;
  final DoctorChatRepository doctorChat;
  final EntitlementRepository entitlements;
}

class RepositoryScope extends InheritedWidget {
  const RepositoryScope({super.key, required this.repos, required super.child});
  final Repositories repos;

  @override
  bool updateShouldNotify(RepositoryScope old) => repos != old.repos;
}

extension RepositoryContext on BuildContext {
  Repositories get repos =>
      getInheritedWidgetOfExactType<RepositoryScope>()!.repos;
}
