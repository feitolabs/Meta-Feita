import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/rules/formatters.dart';
import '../theme/meta_feita_theme.dart';
import 'cards.dart';

class ChartSeriesData {
  final String label;
  final List<FlSpot> spots;
  final Color color;
  final bool dashed;
  final bool fillArea;
  final bool showTerminalDot;

  const ChartSeriesData({
    required this.label,
    required this.spots,
    required this.color,
    this.dashed = false,
    this.fillArea = false,
    this.showTerminalDot = false,
  });
}

class ChartCard extends StatelessWidget {
  final String title;
  final String xAxisUnit;
  final List<ChartSeriesData> seriesList;
  final VoidCallback? onOpenTable;
  final String tableActionLabel;

  const ChartCard({
    super.key,
    required this.title,
    this.xAxisUnit = 'meses',
    required this.seriesList,
    this.onOpenTable,
    this.tableActionLabel = 'Ver tabela mês a mês',
  });

  @override
  Widget build(BuildContext context) {
    final allSpots = seriesList.expand((s) => s.spots).toList();
    if (allSpots.isEmpty) {
      return LightCard(
        child: Text('Sem pontos para exibir.', style: MfText.pequeno),
      );
    }

    final maxX = allSpots.map((s) => s.x).reduce(math.max);
    final minX = allSpots.map((s) => s.x).reduce(math.min);
    final rawMaxY = allSpots.map((s) => s.y).reduce(math.max);
    final rawMinY = allSpots.map((s) => s.y).reduce(math.min);

    final minY = rawMinY < 0 ? rawMinY * 1.05 : 0.0;
    final maxY = rawMaxY <= 0 ? 100.0 : rawMaxY * 1.12;
    final yInterval = math.max(1.0, (maxY - minY) / 3);
    final xSpan = math.max(1.0, maxX - minX);
    final xInterval = xSpan <= 5
        ? 1.0
        : (xSpan / 5).ceilToDouble();

    return LightCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: MfText.tituloCartao),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: seriesList.map((s) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 3,
                    decoration: BoxDecoration(
                      color: s.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    s.label,
                    style: MfText.pequeno.copyWith(
                      color: MfColors.petroleo,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: minX,
                maxX: maxX == minX ? minX + 1 : maxX,
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: MfColors.border,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    bottom: BorderSide(color: MfColors.borderStrong, width: 1),
                    left: BorderSide.none,
                    right: BorderSide.none,
                    top: BorderSide.none,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 56,
                      interval: yInterval,
                      getTitlesWidget: (val, meta) {
                        if (val > maxY * 0.99) return const SizedBox.shrink();
                        final dec = Decimal.parse(val.toStringAsFixed(0));
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            PtBrFormatters.compactMoney(dec),
                            textAlign: TextAlign.right,
                            style: MfText.pequeno.copyWith(fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: xInterval,
                      getTitlesWidget: (val, meta) {
                        final rounded = val.round();
                        if ((val - rounded).abs() > 0.05) {
                          return const SizedBox.shrink();
                        }
                        final isLast = rounded == maxX.round();
                        final label = isLast ? '$rounded $xAxisUnit' : '$rounded';
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            label,
                            style: MfText.pequeno.copyWith(fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => MfColors.petroleo,
                    tooltipBorderRadius: BorderRadius.circular(12),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final s = seriesList[spot.barIndex];
                        final dec = Decimal.parse(spot.y.toStringAsFixed(2));
                        return LineTooltipItem(
                          '${s.label} (${spot.x.round()} $xAxisUnit)\n${PtBrFormatters.money(dec)}',
                          MfText.pequeno.copyWith(
                            color: MfColors.areia,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: seriesList.map((s) {
                  return LineChartBarData(
                    spots: s.spots,
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: s.color,
                    barWidth: s.dashed ? 2.4 : 3.0,
                    dashArray: s.dashed ? const [6, 5] : null,
                    dotData: FlDotData(
                      show: s.showTerminalDot,
                      checkToShowDot: (spot, barData) =>
                          spot.x == barData.spots.last.x,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 4.5,
                        color: MfColors.petroleo,
                        strokeWidth: 2,
                        strokeColor: MfColors.areiaCard,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: s.fillArea,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          MfColors.nevoa.withValues(alpha: 0.42),
                          MfColors.nevoa.withValues(alpha: 0.08),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          if (onOpenTable != null) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: onOpenTable,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  tableActionLabel,
                  style: MfText.rotulo.copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: MfColors.petroleo,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

