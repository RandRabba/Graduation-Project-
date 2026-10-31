import 'package:flutter/foundation.dart';

import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../services/caregiver_repository.dart';
import '../services/mock_caregiver_repository.dart';

/// Single source of truth for the Caregiver module (UI state and data access).
///
/// All reads of patient data go through [repository] with the current
/// [level], so restricted data is never loaded for a Basic caregiver.
class CaregiverController extends ChangeNotifier {
  CaregiverController({
    CaregiverRepository? repository,
    this.showDemoControls = true,
    this.onExit,
  }) : repository = repository ?? MockCaregiverRepository();

  final CaregiverRepository repository;

  /// Shows the prototype controls (access level, theme, data states...).
  /// Turn off in the integrated app.
  final bool showDemoControls;

  /// Called when the user leaves the module from the root of the shell.
  VoidCallback? onExit;

  /// Called with the emergency contact's phone number when the caregiver
  /// taps "Call now". The host app can wire this to `url_launcher`.
  /// When null, the module shows a placeholder message instead.
  ValueChanged<String>? onCall;

  // ---- Session and appearance -------------------------------------------
  AccessLevel _level = AccessLevel.extended;
  bool _dark = false;
  bool _arabic = false;
  DataState _dataState = DataState.normal;
  InvitationState _invitation = InvitationState.pending;
  bool _roleIsPatient = false;

  AccessLevel get level => _level;
  bool get isExtended => _level == AccessLevel.extended;
  bool get isBasic => !isExtended;
  bool get dark => _dark;
  bool get arabic => _arabic;
  DataState get dataState => _dataState;
  InvitationState get invitation => _invitation;

  /// Demo only: pretend the backend returned the PATIENT role after login.
  bool get roleIsPatient => _roleIsPatient;

  AppStrings get strings => AppStrings(_arabic);

  // ---- Navigation --------------------------------------------------------
  int _tabIndex = 0;
  int _resetTick = 0;

  int get tabIndex => _tabIndex;

  /// Incremented whenever every tab should return to its root screen.
  int get resetTick => _resetTick;

  void selectTab(int index) {
    if (index == _tabIndex) return;
    _tabIndex = index;
    notifyListeners();
  }

  // ---- Alerts ------------------------------------------------------------
  final Set<String> _readAlerts = <String>{'a3', 'a4', 'a5'};

  bool isRead(String id) => _readAlerts.contains(id);

  /// Opening an alert only marks it as seen. It never marks it as resolved.
  void markRead(String id) {
    if (_readAlerts.add(id)) notifyListeners();
  }

  /// Alerts the caregiver may see right now (respects access level and the
  /// "no alerts" demo state).
  List<CaregiverAlert> get alerts => _dataState == DataState.noAlerts
      ? const <CaregiverAlert>[]
      : repository.alerts(_level);

  int get unreadCount => alerts.where((a) => !isRead(a.id)).length;

  // ---- Readings ----------------------------------------------------------
  ChartRange _range = ChartRange.week;
  String _typeFilter = 'all';
  String _sourceFilter = 'all';

  ChartRange get range => _range;
  String get typeFilter => _typeFilter;
  String get sourceFilter => _sourceFilter;

  void setRange(ChartRange v) {
    _range = v;
    notifyListeners();
  }

  void setTypeFilter(String v) {
    _typeFilter = v;
    notifyListeners();
  }

  void setSourceFilter(String v) {
    _sourceFilter = v;
    notifyListeners();
  }

  /// The reading shown as "latest", or null for the "no reading" state.
  GlucoseReading? get latestReading => _dataState == DataState.noReading
      ? null
      : repository.latestReading(stale: _dataState == DataState.staleReading);

  // ---- Reports -----------------------------------------------------------
  ReportPeriod _reportPeriod = ReportPeriod.weekly;

  ReportPeriod get reportPeriod => _reportPeriod;

  void setReportPeriod(ReportPeriod v) {
    _reportPeriod = v;
    notifyListeners();
  }

  // ---- Settings ----------------------------------------------------------
  final Map<String, bool> _notif = <String, bool>{
    'high': true,
    'low': true,
    'rep': true,
    'rem': true,
  };

  bool notifEnabled(String key) => _notif[key] ?? true;

  void setNotif(String key, bool value) {
    _notif[key] = value;
    notifyListeners();
  }

  String? _profileName;
  String? _profilePhone;

  String profileName(bool arabic) =>
      _profileName ?? repository.caregiver.name.of(arabic);

  String get profilePhone => _profilePhone ?? repository.caregiver.phone;

  void saveProfile({required String name, required String phone}) {
    _profileName = name.trim().isEmpty ? null : name.trim();
    _profilePhone = phone.trim().isEmpty ? null : phone.trim();
    notifyListeners();
  }

  // ---- Setters used by settings and demo controls -------------------------
  void setDark(bool v) {
    _dark = v;
    notifyListeners();
  }

  void setArabic(bool v) {
    _arabic = v;
    notifyListeners();
  }

  /// Demo only. In the real app the level is set by the patient and comes
  /// from the backend.
  void setLevel(AccessLevel v) {
    _level = v;
    _tabIndex = 0;
    _resetTick++;
    notifyListeners();
  }

  void setDataState(DataState v) {
    _dataState = v;
    notifyListeners();
  }

  void setInvitation(InvitationState v) {
    _invitation = v;
    notifyListeners();
  }

  void setRoleIsPatient(bool v) {
    _roleIsPatient = v;
    notifyListeners();
  }

  /// Disconnect from the patient (after the user confirmed).
  void disconnect() {
    _dataState = DataState.noPatient;
    _tabIndex = 0;
    _resetTick++;
    notifyListeners();
  }

  /// Blocking states replace every screen except Profile and its settings.
  bool get isBlocking =>
      _dataState == DataState.loading ||
      _dataState == DataState.error ||
      _dataState == DataState.revoked ||
      _dataState == DataState.noPatient;
}
