import 'package:flutter/material.dart';

import '../state/caregiver_scope.dart';
import '../theme/app_palette.dart';
import '../theme/text_styles.dart';

/// Pulsing placeholder block. The pulse stops when the system asks to reduce
/// motion.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, required this.height, this.radius = 10});

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.45).animate(_controller),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: context.pal.line,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Placeholder layout shown while patient data loads.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final String text = context.s.t('loadingTxt');
    return Semantics(
      liveRegion: true,
      label: text,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Skeleton(height: 22, width: 150),
            const SizedBox(height: 10),
            const Skeleton(height: 14, width: 100),
            const SizedBox(height: 22),
            const Skeleton(height: 96, radius: 20),
            const SizedBox(height: 14),
            const Skeleton(height: 170, radius: 20),
            const SizedBox(height: 14),
            const Skeleton(height: 56, radius: 16),
            const SizedBox(height: 14),
            const Skeleton(height: 64, radius: 16),
            const SizedBox(height: 18),
            Center(child: Text(text, style: context.subStyle(12.5))),
          ],
        ),
      ),
    );
  }
}
