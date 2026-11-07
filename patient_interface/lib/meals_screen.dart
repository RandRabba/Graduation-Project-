import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'app_state.dart';
import 'common.dart';
import 'l10n.dart';
import 'meal_analysis.dart';
import 'theme.dart';

/// Colour and icon for a meal's glucose impact (always shown with its label).
(Color, IconData) impactStyle(MealImpact i, AppPalette p) => switch (i) {
  MealImpact.good => (p.normal, Icons.check_circle_rounded),
  MealImpact.moderate => (p.caution, Icons.info_rounded),
  MealImpact.high => (p.elevated, Icons.warning_amber_rounded),
};

String _g(double v) => v.toStringAsFixed(0);
String _pct(double v) => '${(v * 100).round()}%';

class MealsScreen extends StatefulWidget {
  const MealsScreen({super.key});

  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  Uint8List? _photo;
  MealType _type = MealType.forTime(DateTime.now());
  MealAnalysis? _result;
  bool _busy = false;
  bool _failed = false;

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = bytes;
        _result = null;
        _failed = false;
      });
    } catch (_) {
      // e.g. no camera on this device, or permission denied
      if (mounted) showSnack(context, context.tr('photo_failed'));
    }
  }

  Future<void> _analyze() async {
    final photo = _photo;
    if (photo == null || _busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final result = await analyzeMeal(photo);
      if (!mounted) return;
      AppScope.read<MealLog>(
        context,
      ).add(MealEntry(photo: photo, analysis: result, type: _type));
      setState(() {
        _result = result;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
  }

  void _reset() => setState(() {
    _photo = null;
    _result = null;
    _failed = false;
  });

  void _open(MealEntry e) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .85,
      maxChildSize: .95,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xl),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.lg),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.memory(e.photo, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: Gap.lg),
          Text(
            ctx.tr(e.type.labelKey),
            style: ctx.text.labelMedium!.copyWith(color: ctx.palette.primary),
          ),
          Text(_when(ctx, e.at), style: ctx.text.bodyMedium),
          const SizedBox(height: Gap.md),
          AnalysisView(e.analysis),
          TextButton.icon(
            onPressed: () {
              AppScope.read<MealLog>(context).remove(e);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: ctx.palette.critical),
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(ctx.tr('meal_delete')),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final log = context.meals;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.xl),
        children: [
          PageHeader(
            context.tr('meals_title'),
            subtitle: context.tr('meals_subtitle'),
          ),
          _today(log.today),
          _upload(),
          if (_failed) _error(),
          if (_result != null) AppCard(child: AnalysisView(_result!)),
          const SizedBox(height: Gap.sm),
          SectionTitle(
            context.tr('recent_meals'),
            subtitle: context.tr('n_meals', {'n': log.entries.length}),
          ),
          const SizedBox(height: Gap.md),
          if (log.entries.isEmpty)
            AppCard(
              child: EmptyState(
                icon: Icons.restaurant_rounded,
                title: context.tr('no_meals'),
                message: context.tr('no_meals_body'),
              ),
            )
          else
            for (final e in log.entries) _MealTile(e, onTap: () => _open(e)),
        ],
      ),
    );
  }

  // ---------- today strip ----------
  Widget _today(List<MealEntry> today) {
    double sum(double Function(MealAnalysis a) f) =>
        today.fold(0, (s, e) => s + f(e.analysis));
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.lg),
      child: StatRow([
        Stat(
          context.tr('meals_today'),
          value: '${today.length}',
          compact: true,
        ),
        Stat(
          context.tr('carbs_short'),
          value: today.isEmpty ? '--' : _g(sum((a) => a.carbs)),
          unit: 'g',
          compact: true,
        ),
        Stat(
          context.tr('calories'),
          value: today.isEmpty ? '--' : _g(sum((a) => a.calories)),
          unit: 'kcal',
          compact: true,
        ),
      ]),
    );
  }

  // ---------- photo + analyze ----------
  Widget _upload() {
    final p = context.palette;
    final photo = _photo;
    return AppCard(
      padding: const EdgeInsets.all(Gap.md + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.md + 2),
            child: photo == null
                ? InkWell(
                    onTap: () => _pick(ImageSource.gallery),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 190),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [p.primarySoft, p.surfaceAlt],
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: Gap.lg,
                        vertical: Gap.xl + 4,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: p.cta,
                            ),
                            child: Icon(
                              Icons.add_a_photo_rounded,
                              color: p.onPrimary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: Gap.md),
                          Text(
                            context.tr('meal_add_photo'),
                            style: context.text.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.tr('meal_photo_tip'),
                            textAlign: TextAlign.center,
                            style: context.text.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  )
                : AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(photo, fit: BoxFit.cover),
                        if (_busy)
                          ColoredBox(
                            color: Colors.black45,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: Gap.md),
                                  Text(
                                    context.tr('meal_analyzing'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          PositionedDirectional(
                            top: Gap.sm,
                            end: Gap.sm,
                            child: IconButton.filled(
                              tooltip: context.tr('meal_remove_photo'),
                              onPressed: _reset,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                              ),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: SoftButton(
                  context.tr('meal_camera'),
                  icon: Icons.photo_camera_rounded,
                  onPressed: _busy ? null : () => _pick(ImageSource.camera),
                ),
              ),
              const SizedBox(width: Gap.sm + 2),
              Expanded(
                child: SoftButton(
                  context.tr('meal_gallery'),
                  icon: Icons.photo_library_rounded,
                  onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md + 2),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final t in MealType.values)
                ChoiceChip(
                  label: Text(context.tr(t.labelKey)),
                  selected: t == _type,
                  showCheckmark: false,
                  onSelected: _busy ? null : (_) => setState(() => _type = t),
                  selectedColor: p.primary,
                  backgroundColor: p.surfaceAlt,
                  side: BorderSide(color: t == _type ? p.primary : p.border),
                  shape: const StadiumBorder(),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: t == _type ? p.onPrimary : p.ink,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          PrimaryButton(
            context.tr(_busy ? 'meal_analyzing' : 'meal_analyze'),
            icon: Icons.auto_awesome_rounded,
            onPressed: photo == null || _busy ? null : _analyze,
          ),
        ],
      ),
    );
  }

  Widget _error() {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: Gap.lg),
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: p.critical.withAlpha(20),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: p.critical.withAlpha(90)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: p.critical),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              context.tr('meal_failed'),
              style: context.text.bodyLarge,
            ),
          ),
          TextButton(onPressed: _analyze, child: Text(context.tr('retry'))),
        ],
      ),
    );
  }
}

String _when(BuildContext context, DateTime at) {
  final loc = MaterialLocalizations.of(context);
  final n = DateTime.now();
  final day = at.year == n.year && at.month == n.month && at.day == n.day
      ? context.tr('today')
      : loc.formatShortMonthDay(at);
  return '$day, ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(at))}';
}

/// Full result of one analysis: accuracy, impact, macros and detected foods.
class AnalysisView extends StatelessWidget {
  const AnalysisView(this.a, {super.key});
  final MealAnalysis a;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (impactColor, impactIcon) = impactStyle(a.impact, p);
    final accuracyKey = a.accuracy >= .85
        ? 'acc_high'
        : a.accuracy >= .65
        ? 'acc_medium'
        : 'acc_low';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr('meal_result'),
                style: context.text.titleMedium,
              ),
            ),
            StatusPill(
              context.tr(a.impact.labelKey),
              impactColor,
              icon: impactIcon,
            ),
          ],
        ),
        if (a.isDemo) ...[
          const SizedBox(height: Gap.md),
          _Note(Icons.science_outlined, context.tr('meal_demo'), p.caution),
        ],
        const SizedBox(height: Gap.lg),
        // accuracy gauge
        Row(
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: a.accuracy,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: p.primarySoft,
                    color: p.primaryBright,
                    semanticsLabel: context.tr('accuracy'),
                    semanticsValue: _pct(a.accuracy),
                  ),
                  Center(
                    child: Text(
                      _pct(a.accuracy),
                      style: context.text.titleMedium!.copyWith(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('accuracy'), style: context.text.titleMedium),
                  const SizedBox(height: 2),
                  Text(context.tr(accuracyKey), style: context.text.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        Row(
          children: [
            Expanded(
              child: StatTile(
                context.tr('carbs_short'),
                Icons.bakery_dining_outlined,
                value: _g(a.carbs),
                unit: 'g',
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: StatTile(
                context.tr('calories'),
                Icons.local_fire_department_outlined,
                value: _g(a.calories),
                unit: 'kcal',
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.md),
        Row(
          children: [
            Expanded(
              child: StatTile(
                context.tr('protein'),
                Icons.fitness_center_rounded,
                value: _g(a.protein),
                unit: 'g',
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: StatTile(
                context.tr('fat'),
                Icons.opacity_rounded,
                value: _g(a.fat),
                unit: 'g',
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: StatTile(
                context.tr('fiber'),
                Icons.grass_rounded,
                value: _g(a.fiber),
                unit: 'g',
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.xl),
        Text(context.tr('detected_foods'), style: context.text.titleMedium),
        const SizedBox(height: Gap.sm),
        for (final f in a.foods) _FoodRow(f),
        const SizedBox(height: Gap.md),
        _Note(
          Icons.health_and_safety_outlined,
          context.tr('meal_safety'),
          p.primary,
        ),
      ],
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow(this.f);
  final FoodItem f;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            f.name,
            style: context.text.bodyLarge!.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            context.tr('food_line', {
              'g': _g(f.grams),
              'c': _g(f.carbs),
              'k': _g(f.calories),
            }),
            style: context.text.labelSmall,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: f.confidence,
                    minHeight: 6,
                    backgroundColor: p.primarySoft,
                    color: p.primaryBright,
                  ),
                ),
              ),
              const SizedBox(width: Gap.sm + 2),
              Text(_pct(f.confidence), style: context.text.labelMedium),
            ],
          ),
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Gap.md),
    decoration: BoxDecoration(
      color: color.withAlpha(22),
      borderRadius: BorderRadius.circular(Radii.md),
      border: Border.all(color: color.withAlpha(60)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: Gap.sm + 2),
        Expanded(
          child: Text(
            text,
            style: context.text.bodyMedium!.copyWith(
              fontSize: 13,
              color: context.palette.ink,
            ),
          ),
        ),
      ],
    ),
  );
}

class _MealTile extends StatelessWidget {
  const _MealTile(this.e, {required this.onTap});
  final MealEntry e;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final a = e.analysis;
    final (color, icon) = impactStyle(a.impact, p);
    return AppCard(
      margin: const EdgeInsets.only(bottom: Gap.sm + 2),
      padding: const EdgeInsets.all(Gap.md),
      onTap: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.sm),
            child: Image.memory(
              e.photo,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${context.tr(e.type.labelKey)} · ${_when(context, e.at)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('meal_tile_line', {
                    'c': _g(a.carbs),
                    'a': _pct(a.accuracy),
                  }),
                  style: context.text.labelMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          StatusPill(context.tr(a.impact.labelKey), color, icon: icon),
        ],
      ),
    );
  }
}
