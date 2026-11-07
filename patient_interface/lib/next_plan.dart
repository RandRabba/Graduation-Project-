import 'dart:async';
import 'package:flutter/material.dart';
import 'common.dart';
import 'l10n.dart';
import 'theme.dart';

/// Summary card that opens the plan generator.
class NextPlanCard extends StatelessWidget {
  const NextPlanCard({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // soft branded header with the illustration
          Container(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.xl, Gap.lg),
            decoration: BoxDecoration(
              color: p.primarySoft,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(Radii.lg),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: p.hero,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: Gap.lg),
                Expanded(
                  child: Text(
                    context.tr('plan_card_title'),
                    style: context.text.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr('plan_card_body'),
                  style: context.text.bodyLarge,
                ),
                const SizedBox(height: Gap.md),
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    for (final (icon, key) in const [
                      (Icons.restaurant_rounded, 'plan_meals'),
                      (Icons.directions_walk_rounded, 'plan_activity'),
                      (Icons.flag_rounded, 'plan_daily'),
                    ])
                      StatusPill(context.tr(key), p.primary, icon: icon),
                  ],
                ),
                const SizedBox(height: Gap.xl),
                PrimaryButton(
                  context.tr('plan_generate'),
                  icon: Icons.auto_awesome_rounded,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NextPlanScreen()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows a short "generating" sequence, then a sample plan (UI demo — no AI is called).
class NextPlanScreen extends StatefulWidget {
  const NextPlanScreen({super.key});

  @override
  State<NextPlanScreen> createState() => _NextPlanScreenState();
}

class _NextPlanScreenState extends State<NextPlanScreen> {
  static const _steps = [
    'plan_step_glucose',
    'plan_step_meals',
    'plan_step_build',
  ];
  static const _goals = [
    'dg_glucose',
    'dg_meals',
    'dg_water',
    'dg_steps',
    'dg_sleep',
  ];

  int _step = 0;
  bool _ready = false;
  bool _saved = false;
  final _done = <String>{};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    _timer?.cancel();
    setState(() {
      _step = 0;
      _ready = false;
      _saved = false;
      _done.clear();
    });
    _timer = Timer.periodic(const Duration(milliseconds: 600), (t) {
      if (!mounted) return t.cancel();
      setState(() {
        if (_step < _steps.length - 1) {
          _step++;
        } else {
          _ready = true;
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SubPage(
    title: context.tr('plan_title'),
    children: [
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _ready
            ? KeyedSubtree(key: const ValueKey('plan'), child: _plan())
            : KeyedSubtree(key: const ValueKey('busy'), child: _generating()),
      ),
    ],
  );

  // ---------- generating ----------
  Widget _generating() {
    final p = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(Gap.xl),
      child: Column(
        children: [
          const SizedBox(height: Gap.md),
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox.expand(
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                Icon(Icons.auto_awesome_rounded, color: p.primary, size: 28),
              ],
            ),
          ),
          const SizedBox(height: Gap.lg),
          Text(context.tr('plan_generating'), style: context.text.titleLarge),
          const SizedBox(height: Gap.lg),
          for (var i = 0; i < _steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.xs + 2),
              child: Row(
                children: [
                  Icon(
                    i < _step
                        ? Icons.check_circle_rounded
                        : (i == _step
                              ? Icons.pending_rounded
                              : Icons.radio_button_unchecked_rounded),
                    color: i <= _step ? p.primary : p.border,
                    size: 22,
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Text(
                      context.tr(_steps[i]),
                      style: context.text.bodyLarge!.copyWith(
                        color: i <= _step ? p.ink : p.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------- plan ----------
  Widget _plan() {
    final p = context.palette;
    final loc = MaterialLocalizations.of(context);
    final n = DateTime.now();
    final from = DateTime(n.year, n.month, n.day + 1);
    final to = DateTime(from.year, from.month, from.day + 6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // overview
        AppCard(
          gradient: p.hero,
          padding: const EdgeInsets.all(Gap.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      context.tr('plan_period', {
                        'from': loc.formatShortMonthDay(from),
                        'to': loc.formatShortMonthDay(to),
                      }),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.xs),
              Text(
                context.tr('plan_based_on'),
                style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 14),
              ),
              const SizedBox(height: Gap.lg),
              Row(
                children: [
                  _HeroNumber(context.tr('plan_avg_glucose'), '142', 'mg/dL'),
                  _HeroNumber(context.tr('time_in_range'), '68', '%'),
                  _HeroNumber(context.tr('plan_avg_carbs'), '175', 'g'),
                ],
              ),
            ],
          ),
        ),
        _Note(Icons.science_outlined, context.tr('plan_sample'), p.caution),
        const SizedBox(height: Gap.md),

        _Section(
          Icons.restaurant_rounded,
          context.tr('plan_meals'),
          children: [
            for (final (meal, key, icon) in const [
              ('meal_breakfast', 'pm_breakfast', Icons.free_breakfast_rounded),
              ('meal_lunch', 'pm_lunch', Icons.lunch_dining_rounded),
              ('meal_dinner', 'pm_dinner', Icons.dinner_dining_rounded),
              ('meal_snack', 'pm_snack', Icons.apple_rounded),
            ])
              _Line(icon, context.tr(meal), context.tr(key)),
            const SizedBox(height: Gap.sm),
            _Note(
              Icons.lightbulb_outline_rounded,
              context.tr('pm_tip'),
              p.primary,
            ),
          ],
        ),

        _Section(
          Icons.pie_chart_outline_rounded,
          context.tr('plan_nutrition'),
          children: [
            for (final (key, target, now, progress) in const [
              ('metric_carbs', '150–180 g', '175 g', .97),
              ('metric_protein', '80 g', '82 g', 1.0),
              ('metric_fat', '≤ 65 g', '64 g', .98),
              ('metric_calories', '1,800 kcal', '1,900 kcal', .95),
              ('fiber', '25 g', '18 g', .72),
            ])
              _Goal(
                context.tr(key),
                target,
                context.tr('plan_now', {'v': now}),
                progress,
              ),
          ],
        ),

        _Section(
          Icons.directions_walk_rounded,
          context.tr('plan_activity'),
          children: [
            _Line(
              Icons.directions_walk_rounded,
              context.tr('pa_walk'),
              context.tr('pa_walk_d'),
            ),
            _Line(
              Icons.restaurant_menu_rounded,
              context.tr('pa_after'),
              context.tr('pa_after_d'),
            ),
            _Line(
              Icons.fitness_center_rounded,
              context.tr('pa_strength'),
              context.tr('pa_strength_d'),
            ),
          ],
        ),

        _Section(
          Icons.flag_rounded,
          context.tr('plan_daily'),
          trailing: Text(
            context.tr('plan_n_done', {
              'n': _done.length,
              'total': _goals.length,
            }),
            style: context.text.labelSmall!.copyWith(color: p.primary),
          ),
          children: [
            for (final g in _goals)
              CheckboxListTile(
                value: _done.contains(g),
                onChanged: (v) =>
                    setState(() => v == true ? _done.add(g) : _done.remove(g)),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: p.primary,
                title: Text(
                  context.tr(g),
                  style: context.text.bodyLarge!.copyWith(
                    decoration: _done.contains(g)
                        ? TextDecoration.lineThrough
                        : null,
                    color: _done.contains(g) ? p.muted : p.ink,
                  ),
                ),
              ),
          ],
        ),

        _Section(
          Icons.spa_outlined,
          context.tr('plan_lifestyle'),
          children: [
            for (final (icon, key) in const [
              (Icons.bedtime_outlined, 'ls_sleep'),
              (Icons.self_improvement_rounded, 'ls_stress'),
              (Icons.local_drink_outlined, 'ls_hydrate'),
              (Icons.health_and_safety_outlined, 'ls_feet'),
            ])
              _Line(icon, null, context.tr(key)),
          ],
        ),

        _Note(
          Icons.health_and_safety_outlined,
          context.tr('plan_disclaimer'),
          p.primary,
        ),
        const SizedBox(height: Gap.lg),
        PrimaryButton(
          context.tr(_saved ? 'plan_saved_btn' : 'plan_save'),
          icon: _saved ? Icons.check_rounded : Icons.bookmark_add_outlined,
          onPressed: _saved
              ? null
              : () {
                  setState(() => _saved = true);
                  showSnack(context, context.tr('plan_saved'));
                },
        ),
        const SizedBox(height: Gap.sm),
        SoftButton(
          context.tr('plan_regenerate'),
          icon: Icons.refresh_rounded,
          onPressed: _generate,
        ),
      ],
    );
  }
}

class _HeroNumber extends StatelessWidget {
  const _HeroNumber(this.label, this.value, this.unit);
  final String label, value, unit;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 13),
              ),
            ],
          ),
        ),
        Text(
          label,
          maxLines: 2,
          style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 12.5),
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section(
    this.icon,
    this.title, {
    required this.children,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconCircle(icon, size: 40),
            const SizedBox(width: Gap.md),
            Expanded(child: Text(title, style: context.text.titleMedium)),
            ?trailing,
          ],
        ),
        const SizedBox(height: Gap.md),
        ...children,
      ],
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.title, this.body);
  final IconData icon;
  final String? title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: p.primary),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: context.text.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(body, style: context.text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A nutrition target with how close the recent average is.
class _Goal extends StatelessWidget {
  const _Goal(this.label, this.target, this.now, this.progress);
  final String label, target, now;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final good = progress >= .9;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.text.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(target, style: context.text.titleMedium),
            ],
          ),
          const SizedBox(height: Gap.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 8,
              backgroundColor: p.border,
              color: good ? p.normal : p.caution,
            ),
          ),
          const SizedBox(height: 2),
          Text(now, style: context.text.labelSmall),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.icon, this.text, this.color);
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(top: Gap.sm),
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: p.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: Gap.sm + 2),
          Expanded(
            child: Text(
              text,
              style: context.text.bodyMedium!.copyWith(fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
