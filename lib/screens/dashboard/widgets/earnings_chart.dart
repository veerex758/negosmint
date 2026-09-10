import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/animated_counter.dart';

class _Period {
  const _Period(this.label, this.total, this.changePct, this.points);
  final String label;
  final double total;
  final double changePct;
  final List<double> points;
}

class EarningsChart extends StatefulWidget {
  const EarningsChart({super.key});

  @override
  State<EarningsChart> createState() => _EarningsChartState();
}

class _EarningsChartState extends State<EarningsChart> {
  int _index = 0;

  static const _periods = [
    _Period('7D', 45.80, 12.5, [4, 6, 5, 9, 7, 12, 10]),
    _Period('1M', 182.40, 8.2, [10, 14, 9, 18, 15, 22, 19, 25, 20, 28, 24, 30]),
    _Period('3M', 520.10, 22.4, [30, 45, 38, 60, 52, 70, 64, 80]),
    _Period('1Y', 2140.75, 34.1, [120, 160, 140, 210, 190, 260, 230, 300, 270, 330, 300, 360]),
  ];

  @override
  Widget build(BuildContext context) {
    final period = _periods[_index];
    final up = period.changePct >= 0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Earnings Overview',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
              Row(
                children: [
                  for (var i = 0; i < _periods.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _index = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: i == _index ? AppColors.brandGradient : null,
                          color: i == _index
                              ? null
                              : AppColors.cobalt.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _periods[i].label,
                          style: TextStyle(
                            color: i == _index
                                ? Colors.white
                                : AppColors.highlight,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          AnimatedCounter(
            value: period.total,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 13, color: up ? AppColors.success : AppColors.danger),
              Text(' ${period.changePct.abs().toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: up ? AppColors.success : AppColors.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppColors.surfaceElevated,
                      getTooltipItems: (spots) => spots
                          .map((s) => LineTooltipItem(
                                '\$${s.y.toStringAsFixed(0)}',
                                const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ))
                          .toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < period.points.length; i++)
                          FlSpot(i.toDouble(), period.points[i]),
                      ],
                      isCurved: true,
                      gradient: AppColors.brandGradient,
                      barWidth: 2.6,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.cobalt.withValues(alpha: 0.25),
                            AppColors.cobalt.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                key: ValueKey(_index),
                duration: const Duration(milliseconds: 400),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
