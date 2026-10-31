import '../models/models.dart';
import 'caregiver_repository.dart';

/// Demonstration data. Clearly separated from real backend data: swap this
/// class for an HTTP-backed [CaregiverRepository] in the integrated app.
class MockCaregiverRepository implements CaregiverRepository {
  MockCaregiverRepository();

  @override
  final Patient patient = const Patient(
    name: LocalizedText('Omar Haddad', 'عمر حداد'),
    initials: LocalizedText('OH', 'عح'),
    diabetesType: LocalizedText('Type 2', 'النوع الثاني'),
    doctorName: LocalizedText('Dr. Hana Saleh', 'د. هناء صالح'),
    clinic: LocalizedText('Al-Amal Diabetes Clinic', 'عيادة الأمل للسكري'),
    emergencyContact: EmergencyContact(
      name: LocalizedText('Samir Haddad', 'سمير حداد'),
      relation: LocalizedText('Father', 'الأب'),
      phone: '+970 59 123 4567',
      initials: LocalizedText('SH', 'سح'),
    ),
    status: PatientStatus.controlled,
  );

  @override
  final CaregiverProfile caregiver = const CaregiverProfile(
    name: LocalizedText('Nour Haddad', 'نور حداد'),
    initials: LocalizedText('NH', 'نح'),
    email: 'nour.haddad@example.com',
    phone: '+970 59 765 4321',
  );

  static final List<GlucoseReading> _readings = <GlucoseReading>[
    GlucoseReading(id: 'r1', value: 168, type: ReadingType.ppbs, source: ReadingSource.sensor, time: DateTime(2026, 10, 30, 8, 12), cls: GlucoseClass.high),
    GlucoseReading(id: 'r2', value: 104, type: ReadingType.fbs, source: ReadingSource.manual, time: DateTime(2026, 10, 30, 7, 5), cls: GlucoseClass.ok),
    GlucoseReading(id: 'r3', value: 62, type: ReadingType.rbs, source: ReadingSource.sensor, time: DateTime(2026, 10, 29, 21, 40), cls: GlucoseClass.low),
    GlucoseReading(id: 'r4', value: 214, type: ReadingType.rbs, source: ReadingSource.manual, time: DateTime(2026, 10, 29, 18, 15), cls: GlucoseClass.high),
    GlucoseReading(id: 'r5', value: 342, type: ReadingType.ppbs, source: ReadingSource.sensor, time: DateTime(2026, 10, 29, 13, 30), cls: GlucoseClass.critHigh),
    GlucoseReading(id: 'r6', value: 131, type: ReadingType.rbs, source: ReadingSource.simulator, time: DateTime(2026, 10, 28, 22, 0), cls: GlucoseClass.ok),
    GlucoseReading(id: 'r7', value: 98, type: ReadingType.fbs, source: ReadingSource.manual, time: DateTime(2026, 10, 28, 7, 0), cls: GlucoseClass.ok),
    GlucoseReading(id: 'r8', value: 48, type: ReadingType.rbs, source: ReadingSource.sensor, time: DateTime(2026, 10, 27, 3, 18), cls: GlucoseClass.critLow),
  ];

  static final HbA1cRecord _hba1c = HbA1cRecord(
    percent: 7.1,
    time: DateTime(2026, 10, 12, 9, 30),
    source: ReadingSource.manual,
  );

  static final List<CaregiverAlert> _alerts = <CaregiverAlert>[
    CaregiverAlert(id: 'a2', kind: AlertKind.low, severity: AlertSeverity.warning, value: 62, time: DateTime(2026, 10, 29, 21, 42), relatedReadingId: 'r3'),
    CaregiverAlert(id: 'a4', kind: AlertKind.repeated, severity: AlertSeverity.warning, time: DateTime(2026, 10, 29, 18, 20), relatedReadingId: 'r4'),
    CaregiverAlert(id: 'a3', kind: AlertKind.high, severity: AlertSeverity.warning, value: 214, time: DateTime(2026, 10, 29, 18, 17), relatedReadingId: 'r4'),
    CaregiverAlert(id: 'a1', kind: AlertKind.critHigh, severity: AlertSeverity.critical, value: 342, time: DateTime(2026, 10, 29, 13, 48), relatedReadingId: 'r5'),
    CaregiverAlert(id: 'a5', kind: AlertKind.critLow, severity: AlertSeverity.critical, value: 48, time: DateTime(2026, 10, 27, 3, 20), relatedReadingId: 'r8'),
  ];

  static const List<LocalizedText> _weekLabels = <LocalizedText>[
    LocalizedText('Sat', 'سبت'),
    LocalizedText('Sun', 'أحد'),
    LocalizedText('Mon', 'إثن'),
    LocalizedText('Tue', 'ثلا'),
    LocalizedText('Wed', 'أرب'),
    LocalizedText('Thu', 'خمي'),
    LocalizedText('Fri', 'جمع'),
  ];

  static List<LocalizedText> _plain(List<String> labels) =>
      labels.map((l) => LocalizedText(l, l)).toList();

  static final Map<ChartRange, ChartSeries> _charts = <ChartRange, ChartSeries>{
    ChartRange.day: ChartSeries(
      const <int>[121, 109, 98, 104, 168],
      _plain(const <String>['00:00', '02:00', '04:00', '06:00', '08:00']),
    ),
    ChartRange.week: const ChartSeries(
      <int>[142, 151, 138, 164, 169, 171, 157],
      _weekLabels,
    ),
    ChartRange.month: ChartSeries(
      const <int>[138, 150, 162, 144, 139, 155, 160, 147, 152, 143],
      _plain(const <String>['1', '4', '7', '10', '13', '16', '19', '22', '25', '28']),
    ),
  };

  static const Map<ChartRange, RangeStats> _stats = <ChartRange, RangeStats>{
    ChartRange.day: RangeStats(
      average: 120,
      inRangePercent: 80,
      count: 5,
      trend: LocalizedText('+64 mg/dL since 07:05', '+64 mg/dL منذ 07:05'),
    ),
    ChartRange.week: RangeStats(
      average: 156,
      inRangePercent: 59,
      count: 34,
      trend: LocalizedText('+4% vs previous week', '+4% عن الأسبوع السابق'),
    ),
    ChartRange.month: RangeStats(
      average: 149,
      inRangePercent: 60,
      count: 138,
      trend: LocalizedText('+2% vs September', '+2% عن سبتمبر'),
    ),
  };

  static const Map<ReportPeriod, List<HealthReport>> _reports = <ReportPeriod, List<HealthReport>>{
    ReportPeriod.daily: <HealthReport>[
      HealthReport(period: ReportPeriod.daily, index: 0, label: LocalizedText('Today so far, Oct 30', 'اليوم حتى الآن، 30 أكتوبر'), average: 120, lowest: 98, highest: 168, count: 5, inRange: 4, high: 1, low: 0, critical: 0, abnormal: 1, criticalAlerts: 0, trend: LocalizedText('+8% vs yesterday', '+8% عن أمس')),
      HealthReport(period: ReportPeriod.daily, index: 1, label: LocalizedText('Yesterday, Oct 29', 'أمس، 29 أكتوبر'), average: 157, lowest: 62, highest: 342, count: 6, inRange: 3, high: 1, low: 1, critical: 1, abnormal: 3, criticalAlerts: 1, trend: LocalizedText('-5% vs previous day', '-5% عن اليوم السابق')),
    ],
    ReportPeriod.weekly: <HealthReport>[
      HealthReport(period: ReportPeriod.weekly, index: 0, label: LocalizedText('Oct 24 – Oct 30', '24 – 30 أكتوبر'), average: 156, lowest: 48, highest: 342, count: 34, inRange: 20, high: 9, low: 3, critical: 2, abnormal: 14, criticalAlerts: 2, trend: LocalizedText('+4% vs previous week', '+4% عن الأسبوع السابق')),
      HealthReport(period: ReportPeriod.weekly, index: 1, label: LocalizedText('Oct 17 – Oct 23', '17 – 23 أكتوبر'), average: 149, lowest: 61, highest: 268, count: 33, inRange: 22, high: 8, low: 3, critical: 0, abnormal: 11, criticalAlerts: 0, trend: LocalizedText('-1% vs previous week', '-1% عن الأسبوع السابق')),
    ],
    ReportPeriod.monthly: <HealthReport>[
      HealthReport(period: ReportPeriod.monthly, index: 0, label: LocalizedText('October 2026 (so far)', 'أكتوبر 2026 (حتى الآن)'), average: 149, lowest: 48, highest: 342, count: 138, inRange: 83, high: 38, low: 11, critical: 6, abnormal: 55, criticalAlerts: 6, trend: LocalizedText('+2% vs September', '+2% عن سبتمبر')),
      HealthReport(period: ReportPeriod.monthly, index: 1, label: LocalizedText('September 2026', 'سبتمبر 2026'), average: 146, lowest: 52, highest: 301, count: 140, inRange: 90, high: 36, low: 10, critical: 4, abnormal: 50, criticalAlerts: 4, trend: LocalizedText('+1% vs August', '+1% عن أغسطس')),
    ],
  };

  static const List<Reminder> _reminders = <Reminder>[
    Reminder(name: LocalizedText('Glucose check before breakfast', 'قياس السكر قبل الإفطار'), type: ReminderType.glucose, time: '07:00', repeat: ReminderRepeat.daily, status: ReminderStatus.done),
    Reminder(name: LocalizedText('Metformin 500 mg', 'ميتفورمين 500 ملغ'), type: ReminderType.medication, time: '08:00', repeat: ReminderRepeat.daily, status: ReminderStatus.missed),
    Reminder(name: LocalizedText('Vitamin D supplement', 'مكمل فيتامين د'), type: ReminderType.medication, time: '13:00', repeat: ReminderRepeat.weekly, status: ReminderStatus.upcoming),
    Reminder(name: LocalizedText('Metformin 500 mg', 'ميتفورمين 500 ملغ'), type: ReminderType.medication, time: '20:00', repeat: ReminderRepeat.daily, status: ReminderStatus.upcoming),
    Reminder(name: LocalizedText('Glucose check after dinner (PPBS)', 'قياس السكر بعد العشاء (PPBS)'), type: ReminderType.glucose, time: '21:00', repeat: ReminderRepeat.daily, status: ReminderStatus.upcoming),
    Reminder(name: LocalizedText('Basal insulin', 'الإنسولين القاعدي'), type: ReminderType.insulin, time: '22:00', repeat: ReminderRepeat.daily, status: ReminderStatus.upcoming),
  ];

  static final List<DoctorInstruction> _instructions = <DoctorInstruction>[
    DoctorInstruction(
      title: const LocalizedText('Morning fasting check', 'قياس الصيام صباحًا'),
      body: const LocalizedText('Keep taking the fasting reading before breakfast each day.', 'استمر في قياس السكر صائمًا قبل الفطور كل يوم.'),
      sharedOn: DateTime(2026, 10, 28),
      doctor: const LocalizedText('Dr. Hana Saleh', 'د. هناء صالح'),
    ),
    DoctorInstruction(
      title: const LocalizedText('Follow-up visit', 'موعد المتابعة'),
      body: const LocalizedText('Review the weekly report together before the next visit.', 'راجعا التقرير الأسبوعي معًا قبل الزيارة القادمة.'),
      sharedOn: DateTime(2026, 10, 25),
      doctor: const LocalizedText('Dr. Hana Saleh', 'د. هناء صالح'),
    ),
  ];

  @override
  GlucoseReading? latestReading({required bool stale}) =>
      stale ? _readings[2] : _readings[0];

  @override
  List<GlucoseReading> readingHistory(AccessLevel level) =>
      level == AccessLevel.extended ? List<GlucoseReading>.unmodifiable(_readings) : const <GlucoseReading>[];

  @override
  HbA1cRecord? hba1c(AccessLevel level) =>
      level == AccessLevel.extended ? _hba1c : null;

  @override
  List<CaregiverAlert> alerts(AccessLevel level) => level == AccessLevel.extended
      ? List<CaregiverAlert>.unmodifiable(_alerts)
      : _alerts.where((a) => a.isCritical).toList(growable: false);

  @override
  GlucoseReading? readingForAlert(CaregiverAlert alert) {
    for (final r in _readings) {
      if (r.id == alert.relatedReadingId) return r;
    }
    return null;
  }

  @override
  ChartSeries? chart(AccessLevel level, ChartRange range) =>
      level == AccessLevel.extended ? _charts[range] : null;

  @override
  RangeStats? rangeStats(AccessLevel level, ChartRange range) =>
      level == AccessLevel.extended ? _stats[range] : null;

  @override
  List<HealthReport> reports(AccessLevel level, ReportPeriod period) =>
      level == AccessLevel.extended ? (_reports[period] ?? const <HealthReport>[]) : const <HealthReport>[];

  @override
  ChartSeries? reportChart(AccessLevel level, HealthReport report) {
    if (level != AccessLevel.extended) return null;
    final base = _charts[_rangeFor(report.period)]!;
    if (report.index == 0) return base;
    return ChartSeries(
      base.values.map((v) => (v * 0.94).round()).toList(growable: false),
      base.labels,
    );
  }

  @override
  List<Reminder> reminders(AccessLevel level) {
    if (level != AccessLevel.extended) return const <Reminder>[];
    final list = List<Reminder>.of(_reminders);
    list.sort((a, b) => a.time.compareTo(b.time));
    return list;
  }

  @override
  List<DoctorInstruction> instructions(AccessLevel level) =>
      level == AccessLevel.extended ? List<DoctorInstruction>.unmodifiable(_instructions) : const <DoctorInstruction>[];

  static ChartRange _rangeFor(ReportPeriod p) {
    switch (p) {
      case ReportPeriod.daily:
        return ChartRange.day;
      case ReportPeriod.weekly:
        return ChartRange.week;
      case ReportPeriod.monthly:
        return ChartRange.month;
    }
  }
}
