import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// 仅 Web 端可用：从 window 读取注入的 JS 密钥
// 注意：本项目为 Web 端，直接使用 dart:html
import 'dart:html' as html;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

enum WalkMode { high, cheap }

class WalkMapWidget extends StatefulWidget {
  final String origin;
  final String destination;
  final String? waypoint; // 新增：经由地
  final Set<String> filters;

  const WalkMapWidget({
    super.key,
    required this.origin,
    required this.destination,
    this.waypoint,
    required this.filters,
  });

  @override
  State<WalkMapWidget> createState() => _WalkMapWidgetState();
}

class _WalkMapWidgetState extends State<WalkMapWidget> {
  late final String _apiKey = _resolveApiKey();

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  LatLng _center = const LatLng(35.681236, 139.767125); // fallback
  bool _loading = true;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRouteAndPlaces();
  }

  String _resolveApiKey() {
    // 优先使用构建时注入；若为空且 Web 端，再尝试从 window.__GMAPS_API_KEY 获取
    const envKey = String.fromEnvironment('GMAPS_API_KEY', defaultValue: '');
    if (envKey.isNotEmpty) return envKey;
    if (kIsWeb) {
      final dynamic jsKey = (html.window as dynamic).__GMAPS_API_KEY;
      if (jsKey is String && jsKey.isNotEmpty) {
        return jsKey;
      }
    }
    return '';
  }

  @override
  void didUpdateWidget(covariant WalkMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 检查起点、终点、经由地或筛选条件是否发生变化
    if (oldWidget.origin != widget.origin ||
        oldWidget.destination != widget.destination ||
        oldWidget.waypoint != widget.waypoint || // 检查经由地变化
        oldWidget.filters.length != widget.filters.length ||
        !oldWidget.filters.containsAll(widget.filters)) {
      // 参数变化时重新加载
      setState(() {
        _loading = true;
        _errorMessage = null;
        _markers.clear();
        _polylines.clear();
      });
      _loadRouteAndPlaces();
    }
  }

  Future<void> _loadRouteAndPlaces() async {
    if (_apiKey.isEmpty) {
      setState(() {
        _loading = false;
        _errorMessage = 'API key 未配置';
      });
      return;
    }
    try {
      final route = await _getRoute();
      // 如果没有路线，直接返回
      if (route.isEmpty) {
        setState(() {
          _loading = false;
          _errorMessage = '未找到路线';
        });
        return;
      }
      
      final sampled = _sampleRoute(route, 10);
      await _getPlacesAlongRoute(sampled);

      if (mounted) {
        setState(() {
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: route,
              color: Colors.blue,
              width: 4,
            ),
          );
          _center = route[route.length ~/ 2];
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = '加载失败: $e';
        });
      }
    }
  }

  /// Directions API
  Future<List<LatLng>> _getRoute() async {
    final params = {
      'origin': widget.origin,
      'destination': widget.destination,
      'mode': 'walking',
      'key': _apiKey,
    };

    // 如果有经由地，添加到参数中
    if (widget.waypoint != null && widget.waypoint!.isNotEmpty) {
      params['waypoints'] = widget.waypoint!;
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      params,
    );

    final res = await http.get(uri);
    
    if (res.statusCode != 200) {
       throw Exception('HTTP Error: ${res.statusCode}');
    }

    final data = jsonDecode(res.body);

    if (data['status'] != 'OK') {
      debugPrint('Directions API Error: ${data['status']} - ${data['error_message']}');
      throw Exception('Directions API error: ${data['status']}');
    }

    final encoded =
        data['routes'][0]['overview_polyline']['points'];

    final points =
        PolylinePoints().decodePolyline(encoded);

    return points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
  }

  /// Python 里的 route_coords[::len//10]
  List<LatLng> _sampleRoute(List<LatLng> route, int count) {
    final step = (route.length / count).floor();
    return [
      for (int i = 0; i < route.length; i += step) route[i]
    ];
  }

  /// Places API
  Future<void> _getPlacesAlongRoute(List<LatLng> points) async {
    // 1. 定义日文标签到 Google Places API types 的映射
    //    可以在这里添加更多类型的映射关系
    final Map<String, List<String>> filterMapping = {
      '買い物さんぽ': ['shopping_mall', 'store'],
      'グルメ\nさんぽ': ['restaurant', 'food'],
      '甘味\nさんぽ': ['cafe', 'bakery'],
      'ゆる\nさんぽ': ['park', 'tourist_attraction'],
    };

    // 2. 根据用户选中的 filters，收集所有需要搜索的 type
    //    如果用户没有选中任何 filter，默认不搜索任何地点 (或者您可以改为默认搜索 restaurant)
    final Set<String> targetTypes = {};
    for (final filter in widget.filters) {
      if (filterMapping.containsKey(filter)) {
        targetTypes.addAll(filterMapping[filter]!);
      }
    }

    // 如果没有选中的类型，直接返回，不进行搜索
    if (targetTypes.isEmpty) return;

    // 3. 对路线上的采样点进行搜索
    for (final p in points) {
      // 遍历所有需要搜索的类型 (注意：Places API 一次请求只能搜一种 type，或者不用 type 用 keyword)
      // 为了简化，这里我们对每种 type 发起一次请求，或者只取第一个 type 搜索
      // 优化方案：这里演示简单遍历搜索第一个匹配的 type
      
      for (final type in targetTypes) {
         final url =
            'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
            '?location=${p.latitude},${p.longitude}'
            '&radius=300' // 搜索半径 300 米
            '&type=$type'
            '&opennow=true'
            '&key=$_apiKey';

        final res = await http.get(Uri.parse(url));
        final data = jsonDecode(res.body);

        for (final place in data['results'] ?? []) {
          final rating = (place['rating'] ?? 0).toDouble();
          final price = place['price_level'] ?? 0; // 0 表示未知，不设下限

          // 这里可以加更多过滤逻辑，比如只要评分 > 3.0
          if (rating >= 3.0) {
            _markers.add(
              Marker(
                markerId: MarkerId(place['place_id']),
                position: LatLng(
                  place['geometry']['location']['lat'],
                  place['geometry']['location']['lng'],
                ),
                infoWindow: InfoWindow(
                  title: place['name'],
                  snippet: '⭐$rating ($type)', // 显示评分和类型
                ),
                // 可以根据 type 设置不同的 icon
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  type == 'park' ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
                ),
              ),
            );
          }
        }
      }
      // 避免触发 API 频率限制
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _errorMessage = null;
                });
                _loadRouteAndPlaces();
              },
              child: const Text('再試行'),
            ),
          ],
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _center,
        zoom: 14,
      ),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      zoomControlsEnabled: false,
    );
  }
}
