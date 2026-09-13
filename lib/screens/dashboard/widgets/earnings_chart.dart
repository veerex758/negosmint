import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/animated_counter.dart';
import '../../../services/auth_service.dart';
import '../../../services/wallet_service.dart';

class _PeriodConfig {
  const _PeriodConfig(this.label, this.days, this.buckets);
  final String label;
  final int days;
  final int buckets;
}

class EarningsChart extends StatefulWidget {
  const EarningsChart({super.key});

  @override
  State<EarningsChart> createState() => _EarningsChartState();
}

class _EarningsChartState extends State<EarningsChart> {
  int _index = 0;

  static const _periods = [
    _PeriodConfig('7D', 7, 7),
    _PeriodConfig('1M', 30, 10),
    _PeriodConfig('3M', 90, 9),
    _PeriodConfig('1Y', 365, 12),
  ];

  final Map<int, Future<EarningsSeries>> _cache = {};

  @override
  void initState() {
    super.initState();
    _fetch(0);
  }

  void _fetch(int index) {
    final userId = AuthService.instance.currentUser?.id;
    if (userId == null) {
      _cache[index] = Future.value(EarningsSeries.zero);
      return;
    }
    final config = _periods[index];
    _cache[index] = WalletService.instance.fetchEarningsSeries(
      userId,
      days: config.days,
      buckets: config.buckets,
    );
  }

  void _selectPeriod(int index) {
    setState(() {
      _index = index;
      if (!_cache.containsKey(index)) {
        _fetch(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
                      onTap: () => _selectPeriod(i),
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
          const SizedBox(height: 12),
          FutureBuilder<EarningsSeries>(
            future: _cache[_index],
            builder: (context, snapshot) {
              final series = snapshot.data ?? EarningsSeries.zero;
              final loading =
                  snapshot.connectionState == ConnectionState.waiting;
              final up = series.changePct >= 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  loading
                      ? const SizedBox(
                          height: 28,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                    AppColors.highlight),
                              ),
                            ),
                          ),
                        )
                      : AnimatedCounter(
                          value: series.total,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w800),
                        ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 13,
                          color: up ? AppColors.success : AppColors.danger),
                      Text(' ${series.changePct.abs().toStringAsFixed(1)}%',
                          style: TextStyle(
                              color: up ? AppColors.success : AppColors.danger,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 110,
                    child: series.points.isEmpty
                        ? const Center(
                            child: Text(
                              'No earnings in this period yet.',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12),
                            ),
                          )
                        : AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            child: LineChart(
                              LineChartData(
                                gridData: const FlGridData(show: false),
                                titlesData: const FlTitlesData(show: false),
                                borderData: FlBorderData(show: false),
                                lineTouchData: LineTouchData(
                                  touchTooltipData: LineTouchTooltipData(
                                    getTooltipColor: (_) =>
                                        AppColors.surfaceElevated,
                                    getTooltipItems: (spots) => spots
                                        .map((s) => LineTooltipItem(
                                              '\$${s.y.toStringAsFixed(0)}',
                                              const TextStyle(
                                                  color:
                                                      AppColors.textPrimary,
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.w600),
                                            ))
                                        .toList(),
                                  ),
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: [
                                      for (var i = 0;
                                          i < series.points.length;
                                          i++)
                                        FlSpot(i.toDouble(), series.points[i]),
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
                                          AppColors.cobalt
                                              .withValues(alpha: 0.25),
                                          AppColors.cobalt
                                              .withValues(alpha: 0),
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
              );
            },
          ),
        ],
      ),
    );
  }
}
