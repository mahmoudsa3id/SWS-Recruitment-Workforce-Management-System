import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/entities/dashboard_summary.dart';

class DashboardPanel extends StatelessWidget {
  const DashboardPanel({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    ),
  );
}

class BalanceDonut extends StatelessWidget {
  const BalanceDonut({
    super.key,
    required this.paid,
    required this.remaining,
    required this.total,
  });

  final double paid;
  final double remaining;
  final double total;

  @override
  Widget build(BuildContext context) {
    final denominator = paid + remaining;
    final paidPercent = denominator <= 0
        ? 0.0
        : (paid / denominator).clamp(0.0, 1.0).toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter = math.min(constraints.maxWidth, 220.0);
        return Column(
          children: [
            SizedBox(
              width: diameter,
              height: diameter,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size.square(diameter),
                    painter: _DonutPainter(
                      segments: [
                        _DonutSegment(paidPercent, AppTheme.green3),
                        _DonutSegment(1 - paidPercent, AppTheme.gold),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'إجمالي الاتفاقات',
                        style: TextStyle(color: AppTheme.muted, fontSize: 11),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        child: Text(
                          _money(total),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'جنيه مصري',
                        style: TextStyle(color: AppTheme.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 18,
              runSpacing: 12,
              children: [
                _LegendDot(
                  color: AppTheme.green3,
                  label: 'المدفوع',
                  value: _money(paid),
                ),
                _LegendDot(
                  color: AppTheme.gold,
                  label: 'المتبقي',
                  value: _money(remaining),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  static String _money(double value) => value.toStringAsFixed(0);
}

class StageDonut extends StatelessWidget {
  const StageDonut({super.key, required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final values = [
      _DonutSegment(summary.stageNew.toDouble(), const Color(0xFFB8C7BE)),
      _DonutSegment(summary.stageSubmitted.toDouble(), const Color(0xFF7FAE9C)),
      _DonutSegment(summary.stageInspected.toDouble(), const Color(0xFF4F8D78)),
      _DonutSegment(summary.stageVisa.toDouble(), AppTheme.gold),
      _DonutSegment(summary.stageFlight.toDouble(), AppTheme.green),
    ];
    final total = summary.totalStageCount;
    final segments = total == 0
        ? [const _DonutSegment(1, AppTheme.border)]
        : values;
    final diameter = 172.0;

    return Row(
      children: [
        SizedBox(
          width: diameter,
          height: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(diameter),
                painter: _DonutPainter(
                  segments: segments,
                  useWeights: total == 0,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$total',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.ink,
                    ),
                  ),
                  const Text(
                    'مسافر',
                    style: TextStyle(fontSize: 11, color: AppTheme.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LegendDot(
                color: values[0].color,
                label: 'جديد',
                value: '${summary.stageNew}',
              ),
              const SizedBox(height: 9),
              _LegendDot(
                color: values[1].color,
                label: 'تقديم',
                value: '${summary.stageSubmitted}',
              ),
              const SizedBox(height: 9),
              _LegendDot(
                color: values[2].color,
                label: 'كشف',
                value: '${summary.stageInspected}',
              ),
              const SizedBox(height: 9),
              _LegendDot(
                color: values[3].color,
                label: 'تأشيرة',
                value: '${summary.stageVisa}',
              ),
              const SizedBox(height: 9),
              _LegendDot(
                color: values[4].color,
                label: 'طيران',
                value: '${summary.stageFlight}',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CashflowBarChart extends StatelessWidget {
  const CashflowBarChart({super.key, required this.points});

  final List<DashboardTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('لا توجد بيانات كافية للرسم البياني.')),
      );
    }
    final maxValue = points.fold<double>(
      0,
      (current, p) => math.max(current, math.max(p.income, p.spending)),
    );
    final scale = maxValue <= 0 ? 1.0 : maxValue;

    return Column(
      children: [
        const Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            _LegendDot(color: AppTheme.green3, label: 'مقبوضات', value: ''),
            _LegendDot(color: AppTheme.gold, label: 'مدفوعات', value: ''),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 190,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final point in points)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _compact(math.max(point.income, point.spending)),
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppTheme.muted,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                        ),
                        const SizedBox(height: 7),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: _Bar(
                                    heightFactor: point.income / scale,
                                    color: AppTheme.green3,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: _Bar(
                                    heightFactor: point.spending / scale,
                                    color: AppTheme.gold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          '${point.monthStart.month}/${point.monthStart.year % 100}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _compact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}م';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}ألف';
    return value.toStringAsFixed(0);
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.heightFactor, required this.color});
  final double heightFactor;
  final Color color;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: heightFactor.clamp(0.02, 1.0).toDouble(),
    child: Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
      ),
    ),
  );
}

class _DonutSegment {
  const _DonutSegment(this.weight, this.color);
  final double weight;
  final Color color;
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.segments, this.useWeights = false});
  final List<_DonutSegment> segments;
  final bool useWeights;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final stroke = radius * .18;
    final rect = Rect.fromCircle(center: center, radius: radius - stroke / 2);
    final total = segments.fold<double>(0, (sum, item) => sum + item.weight);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (final segment in segments) {
      final sweep = (segment.weight / total) * math.pi * 2;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        rect,
        start,
        math.max(0.0, sweep - .035).toDouble(),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.segments != segments || oldDelegate.useWeights != useWeights;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    required this.value,
  });
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 7),
      Flexible(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      if (value.isNotEmpty) ...[
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ],
  );
}
