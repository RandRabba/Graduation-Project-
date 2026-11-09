import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/caregiver_scope.dart';
import '../theme/app_palette.dart';
import '../utils/formatters.dart';
import 'app_card.dart';
import 'app_icon.dart';
import 'patient_style.dart';

/// The patient's latest glucose reading as a dark gradient "hero" card, laid
/// out like the Patient app's summary hero.
///
/// It always says when the value was recorded and that it may not be the
/// current level, and warns when the reading is old. It is read-only: the
/// only action is to open the readings history.
class LatestReadingHero extends StatelessWidget {
  const LatestReadingHero({super.key, required this.onViewReadings});

  final VoidCallback onViewReadings;

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final pal = context.pal;
    final s = c.strings;
    final TextTheme t = Theme.of(context).textTheme;
    final GlucoseReading? r = c.latestReading;
    final bool stale = c.dataState == DataState.staleReading;
    final Patient patient = c.repository.patient;
    const Color soft = Color(0xD9FFFFFF);

    final (String statusKey, Tone statusTone) = patientStatusStyle(patient.status);

    return AppCard(
      gradient: pal.hero,
      margin: const EdgeInsets.only(bottom: CgGap.lg),
      padding: const EdgeInsets.all(CgGap.xl + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  s.t('latest'),
                  style: const TextStyle(color: soft, fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: CgGap.sm),
              Flexible(
                child: Semantics(
                  label: '${s.t('ptStatus')}: ${s.t(statusKey)}',
                  excludeSemantics: true,
                  child: StatusPill(s.t(statusKey), pal.fg(statusTone), onDark: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: CgGap.md),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: r == null ? '--' : '${r.value}',
                  style: t.displaySmall!.copyWith(color: Colors.white, fontSize: 56),
                ),
                TextSpan(
                  text: '  ${s.t('unit')}',
                  style: const TextStyle(fontSize: 17, color: soft),
                ),
              ],
            ),
          ),
          if (r != null) ...<Widget>[
            const SizedBox(height: CgGap.sm),
            StatusPill(
              s.t(r.cls.key),
              glucoseColor(pal, r.cls),
              icon: glucoseIcon(r.cls),
              onDark: true,
            ),
            const SizedBox(height: CgGap.md),
            Text(
              '${s.t('recorded')} ${agoLabel(r.time, s)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            Text(
              '${s.t(r.type.key)} · ${s.t(r.source.key)} · ${whenLabel(r.time, s)}',
              style: const TextStyle(color: soft, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: CgGap.xs),
            Text(s.t('snap'), style: const TextStyle(color: soft, fontSize: 12.5, height: 1.4)),
          ] else ...<Widget>[
            const SizedBox(height: CgGap.sm),
            Text(
              s.t('noRead_t'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            Text(s.t('noRead_b'), style: const TextStyle(color: soft, fontSize: 14, height: 1.4)),
          ],
          if (stale && r != null)
            Semantics(
              liveRegion: true,
              child: Container(
                margin: const EdgeInsets.only(top: CgGap.md),
                padding: const EdgeInsets.symmetric(horizontal: CgGap.md, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(36),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: AppIcon(AppIcons.alert, size: 18, color: Colors.white),
                    ),
                    const SizedBox(width: CgGap.sm),
                    Expanded(
                      child: Text(
                        s.t('staleW'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: CgGap.lg + 2),
          FilledButton(
            onPressed: onViewReadings,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: pal.heroEnd,
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            child: Text(s.t('viewRead')),
          ),
        ],
      ),
    );
  }
}
