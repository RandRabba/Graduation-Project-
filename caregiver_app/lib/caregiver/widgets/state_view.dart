import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/caregiver_scope.dart';
import '../theme/app_palette.dart';
import '../theme/text_styles.dart';
import 'app_icon.dart';
import 'buttons.dart';
import 'skeleton.dart';
import 'toast.dart';

/// Full-page state shown instead of a tab's content when the data cannot be
/// shown: loading, error, access revoked or no linked patient.
class BlockedPage extends StatelessWidget {
  const BlockedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cg;
    final Widget body = c.dataState == DataState.loading
        ? const LoadingView()
        : _MessageView(state: c.dataState);
    return Scaffold(
      backgroundColor: context.pal.bg,
      body: SafeArea(bottom: false, child: body),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.state});

  final DataState state;

  String get _icon {
    switch (state) {
      case DataState.error:
        return AppIcons.cloud;
      case DataState.revoked:
        return AppIcons.userx;
      default:
        return AppIcons.link;
    }
  }

  void _act(BuildContext context) {
    final c = context.cgRead;
    final s = c.strings;
    switch (state) {
      case DataState.error:
        c.setDataState(DataState.normal);
        showToast(context, s.t('updated'), aboveNav: true);
        break;
      case DataState.revoked:
        c.setDataState(DataState.noPatient);
        break;
      case DataState.noPatient:
        showToast(context, s.t('noInv'), aboveNav: true);
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final s = context.s;
    final String key = 'b_${state.name}';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: pal.soft, shape: BoxShape.circle),
              child: AppIcon(_icon, size: 32, color: pal.sec),
            ),
            const SizedBox(height: 14),
            Semantics(
              header: true,
              child: Text(
                s.t('${key}_t'),
                textAlign: TextAlign.center,
                style: context.hStyle(20),
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 290),
              child: Text(
                s.t('${key}_b'),
                textAlign: TextAlign.center,
                style: context.subStyle(14),
              ),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: PrimaryButton(
                label: s.t('${key}_btn'),
                onPressed: () => _act(context),
                minHeight: 48,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
