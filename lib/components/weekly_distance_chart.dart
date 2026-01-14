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

    return Container(
      height: 150, // 稍微增加高度以容纳按钮
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 10, // 固定最大值为 10km，或者可以根据数据动态计算
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, _) {
                            if (value < 0 || value >= dayLabels.length) return const Text('');
                            return Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                dayLabels[value.toInt()],
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: List.generate(weeklyKm.length, (index) {
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: weeklyKm[index],
                            width: 8,
                            borderRadius: BorderRadius.circular(2),
                            color: Colors.green,
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: 10,
                              color: Colors.grey[200],
                            ),
                          ),
                        ],
                      );
                    }),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: InkWell(
              onTap: () {
                // 清空数据确认对话框
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('データ消去'),
                    content: const Text('全ての歩数データを消去しますか？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('キャンセル'),
                      ),
                      TextButton(
                        onPressed: () {
                          stepService.clearAllData();
                          Navigator.pop(ctx);
                        },
                        child: const Text('消去', style: TextStyle(color: Colors.red)),
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
}
