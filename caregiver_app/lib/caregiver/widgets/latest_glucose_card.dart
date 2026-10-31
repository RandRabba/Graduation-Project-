import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/caregiver_scope.dart';
import '../theme/app_palette.dart';
import '../theme/text_styles.dart';
import '../utils/formatters.dart';
import 'app_card.dart';
import 'app_icon.dart';
import 'page_frame.dart';

enum LatestVariant {
  /// Home dashboard: source chip in the header, type and time in one row.
  home,

  /// Readings tab for Basic access: 2x2 grid with every field.
  readings,
}

/// "Latest glucose reading" card. Always shows the time of the reading and
/// that it may not be the current level, and warns when the reading is old.
class LatestGlucoseCard extends StatelessWidget {
  const LatestGlucoseCard({super.key, this.variant = LatestVariant.home});

  final LatestVariant variant;

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final pal = context.pal;
    final s = c.strings;
    final GlucoseReading? r = c.latestReading;
    final bool stale = c.dataState == DataState.staleReading;
    final bool home = variant == LatestVariant.home;

    final Widget header = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              AppIcon(AppIcons.drop, color: pal.sec),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  s.t('latest'),
                  style: TextStyle(color: pal.sec, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        if (home && r != null) AppChip(s.t(r.source.key), fg: pal.sub, bg: pal.bg),
      ],
    );

    if (r == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            header,
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
              child: Column(
                children: <Widget>[
                  Text(s.t('noRead_t'), textAlign: TextAlign.center, style: context.hStyle(16)),
                  const SizedBox(height: 4),
                  Text(s.t('noRead_b'), textAlign: TextAlign.center, style: context.subStyle(13)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final String type = s.t(r.type.key);
    final String source = s.t(r.source.key);
    final String when = whenLabel(r.time, s);
    final String ago = agoLabel(r.time, s);

    final Widget bigNumber = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          '${r.value}',
          style: TextStyle(fontSize: 52, fontWeight: FontWeight.w800, height: 1, color: pal.text),
        ),
        const SizedBox(width: 8),
        Text(s.t('unit'), style: context.subStyle(15)),
        const Spacer(),
        ToneChip(classLabel(r.cls, s), r.cls.tone),
      ],
    );

    final BoxDecoration topLine = BoxDecoration(border: Border(top: BorderSide(color: pal.line)));

    if (!home) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            header,
            const SizedBox(height: 10),
            bigNumber,
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.only(top: 12),
              decoration: topLine,
              child: ColumnGrid(
                children: <Widget>[
                  LabeledValue(label: s.t('rtype'), value: type),
                  LabeledValue(label: s.t('rsrc'), value: source),
                  LabeledValue(label: s.t('rtime'), value: when),
                  LabeledValue(label: s.t('recorded'), value: ago),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(s.t('snap'), style: context.subStyle()),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          header,
          const SizedBox(height: 10),
          bigNumber,
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.only(top: 12),
            decoration: topLine,
            child: Wrap(
              spacing: 22,
              runSpacing: 8,
              children: <Widget>[
                LabeledValue(label: s.t('rtype'), value: type),
                LabeledValue(label: s.t('rtime'), value: when),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: AppIcon(AppIcons.clock, size: 16, color: pal.sub),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: '${s.t('recorded')} $ago.',
                        style: TextStyle(color: pal.text, fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: ' ${s.t('snap')}'),
                    ],
                  ),
                  style: context.subStyle(),
                ),
              ),
            ],
          ),
          if (stale)
            Semantics(
              liveRegion: true,
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: pal.highBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  s.t('staleW'),
                  style: TextStyle(
                    color: pal.high,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
