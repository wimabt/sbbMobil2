import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

import '../design/design_tokens.dart';
import '../services/point_collection_service.dart';

/// Mekan veya rota durağında puan toplama kartı.
///
/// [status] ve [availablePoints] ile durum gösterir;
/// [onCollect] callback'i ile toplama tetiklenir.
class CollectPointsCard extends StatelessWidget {
  const CollectPointsCard({
    super.key,
    required this.state,
    this.onCollect,
    this.compact = false,
  });

  final PointCollectionState state;
  final VoidCallback? onCollect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final status = state.status;

    if (status == PointCollectionStatus.noPoints) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _buildContent(context, isDark, status),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    PointCollectionStatus status,
  ) {
    switch (status) {
      case PointCollectionStatus.noPoints:
        return const SizedBox.shrink();

      case PointCollectionStatus.alreadyCollected:
        return _buildChip(
          context,
          icon: Icons.check_circle,
          label: context.l10n.pointsCollected,
          color: Colors.green,
          isDark: isDark,
        );

      case PointCollectionStatus.campaignUpcoming:
        return _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.schedule_rounded,
          iconColor: isDark ? AppColors.neonBlue : Colors.blueGrey,
          title: context.l10n.campaignUpcoming,
          subtitle: context.l10n.campaignUpcomingHint(state.availablePoints ?? 0),
        );

      case PointCollectionStatus.campaignExpired:
        return _buildChip(
          context,
          icon: Icons.event_busy_rounded,
          label: context.l10n.campaignEnded,
          color: Colors.grey,
          isDark: isDark,
        );

      case PointCollectionStatus.tooFar:
        return _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.stars_rounded,
          iconColor: Colors.orange,
          title: context.l10n.pointsAmount(state.availablePoints ?? 0),
          subtitle: state.distanceMeters != null
              ? context.l10n.pointsApproachWithDist(state.formattedDistance)
              : context.l10n.pointsApproach,
        );

      case PointCollectionStatus.nearby:
        return _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.near_me,
          iconColor: isDark ? AppColors.neonCyan : Colors.blue,
          title: context.l10n.almostThere,
          subtitle:
              context.l10n.pointsApproachMore(state.availablePoints ?? 0, state.formattedDistance),
          pulse: true,
        );

      case PointCollectionStatus.withinRange:
        return _buildCollectButton(context, isDark);

      case PointCollectionStatus.collecting:
        return _buildCollectingState(context, isDark);

      case PointCollectionStatus.collected:
        return _buildCollectedState(context, isDark);

      case PointCollectionStatus.error:
        return _buildErrorState(context, isDark);

      case PointCollectionStatus.velocityAnomaly:
        return _buildErrorState(context, isDark);
    }
  }

  Widget _buildChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      key: ValueKey(label),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 30 : 20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool pulse = false,
  }) {
    final child = Container(
      key: ValueKey(title),
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: isDark
            ? iconColor.withAlpha(15)
            : iconColor.withAlpha(10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: iconColor.withAlpha(isDark ? 40 : 30),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(isDark ? 30 : 20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : null,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!pulse) return child;

    return _PulseWrapper(child: child);
  }

  Widget _buildCollectButton(BuildContext context, bool isDark) {
    final color = isDark ? AppColors.neonOrange : Colors.orange;

    return _ShimmerBorderWrapper(
      accentColor: color,
      isDark: isDark,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onCollect,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: compact ? 10 : 14,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withAlpha(isDark ? 50 : 40),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.star_rounded, size: 24, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.collectPoints,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.earnPoints(state.availablePoints ?? 0),
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).hintColor,
                                ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: color, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollectingState(BuildContext context, bool isDark) {
    return Container(
      key: const ValueKey('collecting'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.neonBlue.withAlpha(15)
            : Theme.of(context).colorScheme.primary.withAlpha(10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isDark
                  ? AppColors.neonBlue
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            context.l10n.collectingPoints,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectedState(BuildContext context, bool isDark) {
    final routeResult = state.routeVisitResult;
    final campaignName = state.visitResult?.campaignName;
    final routeCompleted = routeResult?.routeCompleted == true;
    final message = routeResult?.message ?? state.visitResult?.message;

    // Route stop toplandıktan sonra backend bazen "totalEarnedThisVisit" (durak + bonus)
    // döndürüyor. Kullanıcıya burada sadece rota tamamlama bonusunu göstermek istiyoruz.
    final completionBonus = routeResult?.completionBonus ?? 0;
    final allStopsBonus = routeResult?.allStopsBonus ?? 0;
    final routeBonus = completionBonus + allStopsBonus;

    final earned = routeCompleted
        ? routeBonus
        : (routeResult?.pointsEarned ??
            state.visitResult?.pointsEarned ??
            state.availablePoints ??
            0);

    final Color accentColor = routeCompleted
        ? (isDark ? AppColors.neonOrange : Colors.orange)
        : Colors.green;
    final bgColor = Theme.of(context).colorScheme.surface;
    final borderColor = accentColor.withAlpha(isDark ? 90 : 70);

    return Container(
      key: const ValueKey('collected'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withAlpha(isDark ? 26 : 20),
              shape: BoxShape.circle,
            ),
            child: Icon(
              routeCompleted ? Icons.emoji_events_rounded : Icons.check_rounded,
              size: 24,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routeCompleted
                      ? (earned > 0
                          ? context.l10n.routeCompletedBonus(earned)
                          : context.l10n.routeCompleted)
                      : context.l10n.pointsEarnedExclaim(earned),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                ),
                if (routeCompleted && (completionBonus > 0 || allStopsBonus > 0))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (completionBonus > 0)
                          Text(
                            '+$completionBonus Tamamlama',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).hintColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        if (allStopsBonus > 0)
                          Text(
                            '+$allStopsBonus Tüm Duraklar',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).hintColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                      ],
                    ),
                  ),
                if (message != null && message.isNotEmpty)
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  )
                else if (campaignName != null && campaignName.isNotEmpty)
                  Text(
                    campaignName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, bool isDark) {
    return Container(
      key: const ValueKey('error'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(isDark ? 20 : 10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withAlpha(40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.errorMessage ?? context.l10n.errOccurred,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hafif titreşim efekti — "yakınsınız" durumunda dikkat çekmek için.
class _PulseWrapper extends StatefulWidget {
  const _PulseWrapper({required this.child});

  final Widget child;

  @override
  State<_PulseWrapper> createState() => _PulseWrapperState();
}

class _PulseWrapperState extends State<_PulseWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.85 + (_controller.value * 0.15),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Animated gradient border — butona dikkat çekmek için süpürülen bir ışık efekti.
///
/// CustomPainter ile çizilen dönen gradient border, hafif scale pulse ile
/// premium bir his verir. boxShadow glow'dan çok daha profesyonel.
class _ShimmerBorderWrapper extends StatefulWidget {
  const _ShimmerBorderWrapper({
    required this.accentColor,
    required this.isDark,
    required this.child,
  });

  final Color accentColor;
  final bool isDark;
  final Widget child;

  @override
  State<_ShimmerBorderWrapper> createState() => _ShimmerBorderWrapperState();
}

class _ShimmerBorderWrapperState extends State<_ShimmerBorderWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;

        return CustomPaint(
          painter: _SnakeBorderPainter(
            progress: t,
            accentColor: widget.accentColor,
            isDark: widget.isDark,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [
                  widget.accentColor.withAlpha(widget.isDark ? 30 : 18),
                  widget.accentColor.withAlpha(widget.isDark ? 14 : 8),
                ],
              ),
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// \"Snake\" border - sektör standardı progress border gibi, köşelerde kesilmeden
/// düzgün dolaşan kısa bir vurgu çizgisi.
class _SnakeBorderPainter extends CustomPainter {
  _SnakeBorderPainter({
    required this.progress,
    required this.accentColor,
    required this.isDark,
  });

  final double progress;
  final Color accentColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    // Bir piksel içeri kaydırarak stroke'un kesilmesini engelle
    final rect = Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1);
    if (rect.width <= 0 || rect.height <= 0) return;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));

    final basePaint = Paint()
      ..color = accentColor.withAlpha(isDark ? 80 : 60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // Statik, hafif bir border
    canvas.drawRRect(rrect, basePaint);

    // Hareketli \"snake\" segmenti
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    final iterator = metrics.iterator;
    if (!iterator.moveNext()) return;

    final metric = iterator.current;
    final length = metric.length;
    final segmentLength = length * 0.28; // toplam çevrenin ~%28'i
    final start = length * progress;
    final end = start + segmentLength;

    final snakePaint = Paint()
      ..color = accentColor.withAlpha(isDark ? 220 : 200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;

    Path extract(double from, double to) =>
        metric.extractPath(from.clamp(0, length), to.clamp(0, length));

    if (end <= length) {
      final snakePath = extract(start, end);
      canvas.drawPath(snakePath, snakePaint);
    } else {
      final snakePath1 = extract(start, length);
      final snakePath2 = extract(0, end - length);
      canvas.drawPath(snakePath1, snakePaint);
      canvas.drawPath(snakePath2, snakePaint);
    }
  }

  @override
  bool shouldRepaint(_SnakeBorderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
