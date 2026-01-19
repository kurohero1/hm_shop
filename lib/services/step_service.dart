import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StepService extends ChangeNotifier {
  static const String _storageKey = 'daily_steps_data';
  
  // 存储格式: {'2023-10-27': 5000, '2023-10-28': 7500}
  Map<String, int> _dailySteps = {};
  DateTime _selectedDate = DateTime.now();
  
  Map<String, int> get dailySteps => _dailySteps;
  DateTime get selectedDate => _selectedDate;

  StepService() {
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_storageKey);
    if (data != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(data);
        _dailySteps = decoded.map((key, value) => MapEntry(key, value as int));
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading steps data: $e');
      }
    }
  }

  Future<void> saveStep(DateTime date, int steps) async {
    final key = _formatDate(date);
    _dailySteps[key] = steps;
    notifyListeners();
    await _saveToStorage();
  }

  int getStepsForDate(DateTime date) {
    return _dailySteps[_formatDate(date)] ?? 0;
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  Future<void> clearStepsForDate(DateTime date) async {
    final key = _formatDate(date);
    _dailySteps.remove(key);
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> clearAllData() async {
    _dailySteps.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_dailySteps));
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
  
  // 获取最近7天的数据（用于图表）
  // 返回格式: List<double> (单位 km)
  List<double> getLast7DaysKm() {
    final List<double> result = [];
    final today = DateTime.now();
    
    // 从6天前到今天
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final steps = getStepsForDate(date);
      // 简单换算: 1步 = 0.7米 = 0.0007千米，并保留两位小数
      final km = steps * 0.0007;
      final roundedKm = double.parse(km.toStringAsFixed(2));
      result.add(roundedKm);
    }
    return result;
  }
  
  // 获取最近7天的日期标签
  List<String> getLast7DaysLabels() {
    final List<String> result = [];
    final today = DateTime.now();
    final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      // 获取星期几 (weekday: 1=Mon, 7=Sun)
      result.add(weekdays[date.weekday - 1]);
    }
    return result;
  }
}
