import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

void main() {
  runApp(const MyApp());
}

// アプリ全体
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: '位置情報・天気テスト'),
    );
  }
}

// 画面ウィジェット
class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Padding(
        padding: EdgeInsets.all(12),
        child: WeatherPanel(
          originName: '関屋駅',
          destinationName: '新潟県警察本部',
        ),
      ),
    );
  }
}

class WeatherPanel extends StatefulWidget {
  final String originName;
  final String destinationName;
  final String waypointName;
  final double? originLat;
  final double? originLon;
  final double? destinationLat;
  final double? destinationLon;
  final void Function(String)? onSystemCommentChanged;

  const WeatherPanel({
    super.key,
    required this.originName,
    required this.destinationName,
    this.waypointName = '',
    this.originLat,
    this.originLon,
    this.destinationLat,
    this.destinationLon,
    this.onSystemCommentChanged,
  });

  @override
  State<WeatherPanel> createState() => _WeatherPanelState();
}

class _PlaceWeather {
  final String query;
  final String displayName;
  final double? nowTemp;
  final double? maxTemp;
  final double? minTemp;
  final String weatherJa;

  const _PlaceWeather({
    required this.query,
    required this.displayName,
    required this.nowTemp,
    required this.maxTemp,
    required this.minTemp,
    required this.weatherJa,
  });
}

class _WeatherPanelState extends State<WeatherPanel> {
  _PlaceWeather? _originWeather;
  _PlaceWeather? _waypointWeather;
  _PlaceWeather? _destinationWeather;
  Timer? _timer;
  String _systemComment = '';

  @override
  void initState() {
    super.initState();
    _loadAllWeather();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) {
      _loadAllWeather();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WeatherPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.originName != widget.originName ||
        oldWidget.waypointName != widget.waypointName ||
        oldWidget.destinationName != widget.destinationName ||
        oldWidget.originLat != widget.originLat ||
        oldWidget.originLon != widget.originLon ||
        oldWidget.destinationLat != widget.destinationLat ||
        oldWidget.destinationLon != widget.destinationLon) {
      _loadAllWeather();
    }
  }

  bool _hasMeaningfulData(_PlaceWeather? w) {
    if (w == null) return false;
    if (w.nowTemp != null) return true;
    if (w.maxTemp != null) return true;
    if (w.minTemp != null) return true;
    if (w.weatherJa.isNotEmpty) return true;
    return false;
  }

  _PlaceWeather? _pickBetterWeather(_PlaceWeather? oldValue, _PlaceWeather? newValue) {
    if (newValue == null) return oldValue;
    if (!_hasMeaningfulData(newValue) && _hasMeaningfulData(oldValue)) {
      return oldValue;
    }
    return newValue;
  }

  Future<void> _loadAllWeather() async {
    final origin = widget.originName.trim();
    final waypoint = widget.waypointName.trim();
    final destination = widget.destinationName.trim();
    if (origin.isEmpty && waypoint.isEmpty && destination.isEmpty) {
      return;
    }
    try {
      final originFuture = widget.originLat != null && widget.originLon != null
          ? _fetchWeatherByCoords(origin, widget.originLat!, widget.originLon!)
          : _fetchPlaceWeather(origin);
      final waypointFuture =
          waypoint.isNotEmpty ? _fetchPlaceWeather(waypoint) : Future.value(null);
      final destinationFuture =
          widget.destinationLat != null && widget.destinationLon != null
              ? _fetchWeatherByCoords(
                  destination, widget.destinationLat!, widget.destinationLon!)
              : _fetchPlaceWeather(destination);
      final results = await Future.wait<_PlaceWeather?>([
        originFuture,
        waypointFuture,
        destinationFuture,
      ]);
      if (!mounted) return;
      setState(() {
        _originWeather = _pickBetterWeather(_originWeather, results[0]);
        _waypointWeather = _pickBetterWeather(_waypointWeather, results[1]);
        _destinationWeather =
            _pickBetterWeather(_destinationWeather, results[2]);
        _systemComment = _buildSystemComment();
      });
      if (widget.onSystemCommentChanged != null) {
        widget.onSystemCommentChanged!(_systemComment);
      }
    } catch (_) {}
  }

  String _buildSystemComment() {
    _PlaceWeather? target;
    if (_hasMeaningfulData(_destinationWeather)) {
      target = _destinationWeather;
    } else if (_hasMeaningfulData(_waypointWeather)) {
      target = _waypointWeather;
    } else if (_hasMeaningfulData(_originWeather)) {
      target = _originWeather;
    } else {
      return '';
    }

    final t = target!;
    final now = t.nowTemp;
    final maxT = t.maxTemp;
    final minT = t.minTemp;
    final desc = t.weatherJa;

    if (desc.contains('雨')) {
      return '雨の可能性があります。傘を持って行ったほうがいいかもしれません。';
    }
    if (desc.contains('雪')) {
      return '雪の予報です。足元に注意してください。';
    }
    if ((maxT ?? now ?? 0) >= 30) {
      return '気温が高めです。こまめに水分補給をして熱中症に注意しましょう。';
    }
    if ((minT ?? now ?? 100) <= 0) {
      return '気温がかなり低いです。暖かい服装でお出かけください。';
    }
    if (desc.contains('霧')) {
      return '霧の可能性があります。視界に注意して行動してください。';
    }
    return 'お出かけしやすい天気です。無理のないペースでさんぽを楽しみましょう。';
  }

  Future<_PlaceWeather?> _fetchWeatherByCoords(
      String query, double lat, double lon) async {
    final displayName = query;
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat'
      '&longitude=$lon'
      '&current_weather=true'
      '&daily=weathercode,temperature_2m_max,temperature_2m_min'
      '&timezone=Asia/Tokyo',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      return _PlaceWeather(
        query: query,
        displayName: displayName,
        nowTemp: null,
        maxTemp: null,
        minTemp: null,
        weatherJa: '',
      );
    }

    final data = jsonDecode(response.body);
    final daily = data['daily'];
    final current = data['current_weather'];
    if (daily == null || current == null) {
      return _PlaceWeather(
        query: query,
        displayName: displayName,
        nowTemp: null,
        maxTemp: null,
        minTemp: null,
        weatherJa: '',
      );
    }

    final maxTemp = (daily['temperature_2m_max'][0] as num).toDouble();
    final minTemp = (daily['temperature_2m_min'][0] as num).toDouble();
    final nowTemp = (current['temperature'] as num).toDouble();
    final int weatherCode = current['weathercode'];

    final weatherJa = _weatherCodeToJa(weatherCode);

    return _PlaceWeather(
      query: query,
      displayName: displayName,
      nowTemp: nowTemp,
      maxTemp: maxTemp,
      minTemp: minTemp,
      weatherJa: weatherJa,
    );
  }

  Future<_PlaceWeather?> _fetchPlaceWeather(String query) async {
    if (query.isEmpty) return null;

    final trimmed = query.trim();
    final candidateSet = <String>{};
    if (trimmed.isNotEmpty) {
      candidateSet.add(trimmed);
    }
    if (trimmed.contains('駅')) {
      final withoutEki = trimmed.replaceAll('駅', '').trim();
      if (withoutEki.isNotEmpty) {
        candidateSet.add(withoutEki);
      }
    }
    const adminTokens = ['都', '道', '府', '県', '市', '区', '町', '村'];
    int cutIndex = -1;
    for (final token in adminTokens) {
      final idx = trimmed.indexOf(token);
      if (idx != -1) {
        final end = idx + token.length;
        if (end < trimmed.length) {
          cutIndex = cutIndex == -1 ? end : (end < cutIndex ? end : cutIndex);
        }
      }
    }
    if (cutIndex != -1) {
      final adminPart = trimmed.substring(0, cutIndex).trim();
      if (adminPart.isNotEmpty) {
        candidateSet.add(adminPart);
      }
    }
    for (final token in adminTokens) {
      final idx = trimmed.indexOf(token);
      if (idx != -1) {
        final end = idx + token.length;
        final head = trimmed.substring(0, end).trim();
        if (head.isNotEmpty) {
          candidateSet.add(head);
        }
        if (end < trimmed.length) {
          final tail = trimmed.substring(end).trim();
          if (tail.isNotEmpty) {
            candidateSet.add(tail);
          }
        }
      }
    }
    if (!trimmed.contains('駅') && trimmed.length <= 3) {
      var hasAdminToken = false;
      for (final token in adminTokens) {
        if (trimmed.contains(token)) {
          hasAdminToken = true;
          break;
        }
      }
      if (!hasAdminToken) {
        const suffixes = ['市', '府', '県', '都'];
        for (final s in suffixes) {
          candidateSet.add('$trimmed$s');
        }
      }
    }
    final candidates = candidateSet.toList();

    Map<String, dynamic>? first;

    for (final name in candidates) {
      final encoded = Uri.encodeComponent(name);
      final urls = [
        Uri.parse(
          'https://geocoding-api.open-meteo.com/v1/search'
          '?name=$encoded'
          '&count=1'
          '&language=ja'
          '&format=json'
          '&countryCode=JP',
        ),
        Uri.parse(
          'https://geocoding-api.open-meteo.com/v1/search'
          '?name=$encoded'
          '&count=1',
        ),
      ];

      for (final url in urls) {
        final geoRes = await http.get(url);
        if (geoRes.statusCode != 200) {
          continue;
        }

        final geoData = jsonDecode(geoRes.body);
        final results = geoData['results'];
        if (results == null || results is! List || results.isEmpty) {
          continue;
        }

        first = Map<String, dynamic>.from(results[0] as Map);
        break;
      }

      if (first != null) {
        break;
      }
    }

    if (first == null) {
      return _PlaceWeather(
        query: query,
        displayName: query,
        nowTemp: null,
        maxTemp: null,
        minTemp: null,
        weatherJa: '',
      );
    }

    final lat = (first['latitude'] as num).toDouble();
    final lon = (first['longitude'] as num).toDouble();
    final name = (first['name'] ?? query) as String;
    final admin1 = first['admin1'] as String?;
    final admin2 = first['admin2'] as String?;
    final parts = <String>[];
    if (name.isNotEmpty) parts.add(name);
    if (admin1 != null && admin1.isNotEmpty) parts.add(admin1);
    if (admin2 != null && admin2.isNotEmpty) parts.add(admin2);
    final displayName = parts.isNotEmpty ? parts.join(' ') : name;

    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat'
      '&longitude=$lon'
      '&current_weather=true'
      '&daily=weathercode,temperature_2m_max,temperature_2m_min'
      '&timezone=Asia/Tokyo',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      return _PlaceWeather(
        query: query,
        displayName: displayName,
        nowTemp: null,
        maxTemp: null,
        minTemp: null,
        weatherJa: '',
      );
    }

    final data = jsonDecode(response.body);
    final daily = data['daily'];
    final current = data['current_weather'];
    if (daily == null || current == null) {
      return _PlaceWeather(
        query: query,
        displayName: displayName,
        nowTemp: null,
        maxTemp: null,
        minTemp: null,
        weatherJa: '',
      );
    }

    final maxTemp = (daily['temperature_2m_max'][0] as num).toDouble();
    final minTemp = (daily['temperature_2m_min'][0] as num).toDouble();
    final nowTemp = (current['temperature'] as num).toDouble();
    final int weatherCode = current['weathercode'];

    final weatherJa = _weatherCodeToJa(weatherCode);

    return _PlaceWeather(
      query: query,
      displayName: displayName,
      nowTemp: nowTemp,
      maxTemp: maxTemp,
      minTemp: minTemp,
      weatherJa: weatherJa,
    );
  }

  String _weatherCodeToJa(int code) {
    switch (code) {
      case 0:
        return '快晴';
      case 1:
        return 'ほぼ快晴';
      case 2:
        return '晴れ時々曇り';
      case 3:
        return '曇り';
      case 45:
      case 48:
        return '霧';
      case 51:
      case 53:
      case 55:
        return '霧雨';
      case 56:
      case 57:
        return '着氷性の霧雨';
      case 61:
      case 63:
      case 65:
        return '雨';
      case 66:
      case 67:
        return '着氷性の雨';
      case 71:
      case 73:
      case 75:
        return '雪';
      case 77:
        return '雪粒';
      case 80:
      case 81:
      case 82:
        return 'にわか雨';
      case 85:
      case 86:
        return 'にわか雪';
      case 95:
        return '雷雨';
      case 96:
      case 99:
        return '雷雨（ひょう）';
      default:
        return '不明';
    }
  }

  Widget _buildPlaceColumn(String label, String query, _PlaceWeather? data) {
    final displayName =
        (data?.displayName.isNotEmpty ?? false) ? data!.displayName : query;
    final nowTemp = data?.nowTemp;
    final maxTemp = data?.maxTemp;
    final minTemp = data?.minTemp;
    final weatherJa = data?.weatherJa ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          displayName,
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          nowTemp != null ? '${nowTemp.toStringAsFixed(1)} ℃' : '-- ℃',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text('最高気温： ${maxTemp?.toStringAsFixed(1) ?? '--'} ℃'),
        Text('最低気温： ${minTemp?.toStringAsFixed(1) ?? '--'} ℃'),
        const SizedBox(height: 4),
        Text(weatherJa),
      ],
    );
  }

  // ===== 画面 =====
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '天気予報',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (_systemComment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _systemComment,
              style: const TextStyle(
                color: Color(0xFF2FA84F),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPlaceColumn(
                  '出発地',
                  widget.originName,
                  _originWeather,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPlaceColumn(
                  '経由地',
                  widget.waypointName,
                  _waypointWeather,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPlaceColumn(
                  '目的地',
                  widget.destinationName,
                  _destinationWeather,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
