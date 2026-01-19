import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hm_shop/services/step_service.dart';
import 'package:provider/provider.dart';

class WeeklyDistanceChart extends StatelessWidget {
  const WeeklyDistanceChart({super.key});

  @override
  Widget build(BuildContext context) {
    // 从 Service 获取数据，监听变化自动刷新
    final stepService = context.watch<StepService>();
    final weeklyKm = stepService.getLast7DaysKm();
    final dayLabels = stepService.getLast7DaysLabels();
    final totalKm = weeklyKm.fold<double>(0, (sum, v) => sum + v);

    return Container(
      height: 210,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        centerSpaceRadius: 32,
                        sectionsSpace: 2,
                        startDegreeOffset: -90,
                        sections: _buildSections(weeklyKm, dayLabels, totalKm),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '合計',
                          style: TextStyle(fontSize: 10),
                        ),
                        Text(
                          '${totalKm.toStringAsFixed(2)} km',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '直近7日',
                style: TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 2,
                children: [
                  for (int i = 0; i < weeklyKm.length; i++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: weeklyKm[i] > 0 ? _segmentColor(i) : Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          dayLabels[i],
                          style: TextStyle(
                            fontSize: 10,
                            color: weeklyKm[i] > 0 ? Colors.black87 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('データリセット'),
                    content: const Text('現在表示中の日付の歩数だけリセットしますか？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('キャンセル'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final targetDate = stepService.selectedDate;
                          await stepService.clearStepsForDate(targetDate);
                          Navigator.pop(ctx);
                        },
                        child: const Text('リセット', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline, size: 14, color: Colors.grey),
                  SizedBox(width: 2),
                  Text('リセット', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _segmentColor(int index) {
    final colors = [
      Colors.green.shade700,
      Colors.green.shade500,
      Colors.green.shade300,
      Colors.lightGreen.shade400,
      Colors.lightGreen.shade600,
      Colors.teal.shade400,
      Colors.teal.shade700,
    ];
    return colors[index % colors.length];
  }

  List<PieChartSectionData> _buildSections(
    List<double> weeklyKm,
    List<String> dayLabels,
    double totalKm,
  ) {
    if (totalKm == 0) {
      return [
        PieChartSectionData(
          value: 1,
          color: Colors.grey[300],
          showTitle: false,
        ),
      ];
    }

    return List.generate(weeklyKm.length, (index) {
      final value = weeklyKm[index];
      if (value <= 0) {
        return PieChartSectionData(
          value: 0,
          showTitle: false,
          color: Colors.transparent,
        );
      }

      final title = '${dayLabels[index]} ${value.toStringAsFixed(1)}';
      return PieChartSectionData(
        value: value,
        color: _segmentColor(index),
        title: title,
        titleStyle: const TextStyle(
          fontSize: 8,
          color: Colors.white,
        ),
        titlePositionPercentageOffset: 0.7,
      );
    });
  }
}
