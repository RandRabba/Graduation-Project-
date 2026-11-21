import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../services/caregiver_auth.dart';
import '../services/caregiver_repository.dart';
import '../services/mock_caregiver_auth.dart';
import '../services/mock_caregiver_repository.dart';
import '../utils/dialer.dart';

/// Single source of truth for the Caregiver module (UI state and data access).
///
/// All reads of patient data go through [repository] with the current
/// [level] (fixed to extended: the caregiver sees one read-only set of
/// screens, see [AccessLevel]). Sign in and registration go through [auth].
class CaregiverController extends ChangeNotifier {
  CaregiverController({
    CaregiverRepository? repository,
    CaregiverAuth? auth,
    this.showDemoControls = false,
    this.onExit,
  })  : repository = repository ?? MockCaregiverRepository(),
        _auth = auth {
    // A live backend reports new data (and loading / error states) here.
    this.repository.changes?.addListener(notifyListeners);
  }

  final CaregiverRepository repository;

  final CaregiverAuth? _auth;

  /// Sign in, registration and password handling. The demo implementation is
  /// used unless the host passes a real one.
  late final CaregiverAuth auth = _auth ??
      MockCaregiverAuth(repository: repository, isPatientAccount: () => _roleIsPatient);

  /// True when [repository] is a live backend, so the demo data-state
  /// controls have no say.
  bool get isLive => repository.liveState != null;

  @override
  void dispose() {
    repository.changes?.removeListener(notifyListeners);
    super.dispose();
  }

  /// Shows the prototype controls (theme, language, data states...).
  /// Turn off in the integrated app.
  final bool showDemoControls;

  /// Called when the user leaves the module from the root of the shell.
  VoidCallback? onExit;

  /// Called with the emergency contact's phone number when the caregiver
  /// taps a call button. The host app can wire this to its own dialer.
  /// When null, the module opens the device dialer itself (`tel:` link).
  ValueChanged<String>? onCall;

  /// Calls [phone]: through [onCall] when the host supplied one, otherwise
  /// with the device dialer. Returns false when no call could be started.
  Future<bool> callPhone(String phone) async {
    final ValueChanged<String>? hook = onCall;
    if (hook != null) {
      hook(phone);
      return true;
    }
    return dialPhone(phone);
  }

  // ---- Session and appearance -------------------------------------------
  AccessLevel _level = AccessLevel.extended;
  /// Follows the device by default, like the Patient app.
  ThemeMode _themeMode = ThemeMode.system;
  bool _arabic = false;
  DataState _dataState = DataState.normal;
  bool _roleIsPatient = false;

  AccessLevel get level => _level;
  ThemeMode get themeMode => _themeMode;
  bool get arabic => _arabic;

  /// A live backend decides the state (loading, error, no linked patient);
  /// otherwise the demo controls do.
  DataState get dataState => repository.liveState ?? _dataState;

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

  /// True when the readings list is narrowed by type or source.
  bool get filtersActive => _typeFilter != 'all' || _sourceFilter != 'all';

  void resetFilters() {
    _typeFilter = 'all';
    _sourceFilter = 'all';
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
    unawaited(repository.saveCaregiverProfile(name: name, phone: phone));
  }

  // ---- Setters used by settings and demo controls -------------------------
  void setThemeMode(ThemeMode v) {
    if (v == _themeMode) return;
    _themeMode = v;
    notifyListeners();
  }

  void setArabic(bool v) {
    _arabic = v;
    notifyListeners();
  }

  /// Kept for a future tiered product. No screen calls it today.
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
    unawaited(repository.disconnect());
  }

  /// "Try again" / "Check again": a live backend loads everything again.
  void refresh() {
    if (isLive) unawaited(repository.reload());
  }

  /// Signs out and clears what the previous account was looking at.
  Future<void> signOut() async {
    await auth.signOut();
    _tabIndex = 0;
    _resetTick++;
    _dataState = DataState.normal;
    _profileName = null;
    _profilePhone = null;
    resetFilters();
  }

  /// Blocking states replace every screen except Profile and its settings.
  bool get isBlocking =>
      dataState == DataState.loading ||
      dataState == DataState.error ||
      dataState == DataState.revoked ||
      dataState == DataState.noPatient;
}
