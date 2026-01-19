import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hm_shop/services/step_service.dart';
import 'package:pedometer/pedometer.dart';
import 'package:provider/provider.dart';

class StepCounter extends StatefulWidget {
  const StepCounter({super.key});

  @override
  State<StepCounter> createState() => _StepCounterState();
}

class _StepCounterState extends State<StepCounter> {
  int _currentSteps = 0; // 当日实时步数（传感器）
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _manualInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initPedometer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<StepService>().setSelectedDate(_selectedDate);
    });
  }
  
  @override
  void dispose() {
    _manualInputController.dispose();
    super.dispose();
  }

  void _initPedometer() {
    // Web环境不支持计步器传感器
    if (kIsWeb) return;

    try {
      Pedometer.stepCountStream.listen(
        (event) {
          if (mounted) {
            setState(() {
              _currentSteps = event.steps;
            });
            // 自动保存今日步数（如果选择了今天）
            if (_isToday(_selectedDate)) {
               context.read<StepService>().saveStep(DateTime.now(), _currentSteps);
            }
          }
        },
        onError: (error) {
          debugPrint('Pedometer error: $error');
        },
      );
    } catch (e) {
      debugPrint('Pedometer init failed: $e');
    }
  }
  
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ja'), // 如果配置了本地化
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      context.read<StepService>().setSelectedDate(picked);
    }
  }
  
  void _saveManualSteps() {
    final steps = int.tryParse(_manualInputController.text);
    if (steps != null) {
      context.read<StepService>().saveStep(_selectedDate, steps);
      _manualInputController.clear();
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存しました')),
      );
    }
  }

  String _formatSteps(int steps) {
    final s = steps.toString();
    if (s.length <= 7) {
      return s;
    }
    if (steps >= 100000000) {
      return '${(steps / 100000000).toStringAsFixed(1)}億+';
    }
    if (steps >= 10000) {
      return '${(steps / 10000).toStringAsFixed(1)}万+';
    }
    return s.substring(0, 7);
  }

  @override
  Widget build(BuildContext context) {
    // 从 Service 获取选中日期的步数
    final stepService = context.watch<StepService>();
    final savedSteps = stepService.getStepsForDate(_selectedDate);
    
    // 如果是今天，且传感器有数据，优先显示传感器数据（或者两者取大，视需求而定）
    // 这里简单处理：显示 Service 中保存的数据，如果是今天且传感器有更新，Service 应该也被更新了
    // 但为了支持手动修改今天的数据，我们以 Service 为准。
    // *注意*：实际逻辑中，传感器更新时应该不断 update Service。上面 listen 里已经做了。
    
    final displaySteps = savedSteps;
    final km = (displaySteps * 0.7 / 1000).toStringAsFixed(2);
    final displayStepsText = _formatSteps(displaySteps);
    final kmText = '$km km';
    final dateStr = "${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day}";

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          // 顶部：日期选择
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('歩数カウンター', style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () => _selectDate(context),
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(dateStr),
              ),
            ],
          ),
          const Divider(),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    displayStepsText,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const Text(' 歩', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 16),
                  Text(
                    kmText,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          
          // 底部：手动输入
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _manualInputController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '歩数を手入力',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saveManualSteps,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
