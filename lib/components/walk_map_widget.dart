import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// 仅 Web 端可用：从 window 读取注入的 JS 密钥
// 注意：本项目为 Web 端，直接使用 dart:html
import 'dart:html' as html;
import 'dart:js' as js;
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
      try {
        final hasProp = (js.context as dynamic).hasProperty('__GMAPS_API_KEY');
        final dynamic jsKey = hasProp == true ? js.context['__GMAPS_API_KEY'] : null;
        if (jsKey is String && jsKey.isNotEmpty) return jsKey;
      } catch (_) {}
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
          _loading = false; // 先展示地图与路线
        });
      }

      // Web 上直接调用 Places REST 也会遇到 CORS 限制，这里仅在非 Web 环境请求
      final sampled = _sampleRoute(route, 10);
      if (kIsWeb) {
        _loadPlacesAlongRouteWeb(sampled);
      } else {
        Future(() async {
          await _getPlacesAlongRoute(sampled);
          if (mounted) {
            setState(() {});
          }
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
    if (kIsWeb) {
      return _getRouteViaJsDirections();
    }
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

    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    
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

  Future<List<LatLng>> _getRouteViaJsDirections() {
    final completer = Completer<List<LatLng>>();
    try {
      final google = js.context['google'];
      if (google == null) {
        completer.completeError(Exception('Google Maps JS SDK not available'));
        return completer.future;
      }
      final maps = (google as js.JsObject)['maps'];
      if (maps == null) {
        completer.completeError(Exception('Google Maps maps namespace missing'));
        return completer.future;
      }
      final directionsCtor = maps['DirectionsService'];
      if (directionsCtor == null) {
        completer.completeError(Exception('DirectionsService constructor missing'));
        return completer.future;
      }
      final directionsService = js.JsObject(directionsCtor as js.JsFunction, const []);
      final request = js.JsObject.jsify({
        'origin': widget.origin,
        'destination': widget.destination,
        'travelMode': 'WALKING',
      });
      directionsService.callMethod('route', [
        request,
        (result, status) {
          if (status != 'OK') {
            completer.completeError(Exception('Directions status: $status'));
            return;
          }
          final routes = result['routes'];
          if (routes == null || routes.length == 0) {
            completer.complete(<LatLng>[]);
            return;
          }
          final route0 = routes[0];
          final overviewPath = route0['overview_path'];
          final pts = <LatLng>[];
          for (var i = 0; i < overviewPath.length; i++) {
            final p = overviewPath[i] as js.JsObject;
            final lat = p.callMethod('lat') as num;
            final lng = p.callMethod('lng') as num;
            pts.add(LatLng(lat.toDouble(), lng.toDouble()));
          }
          completer.complete(pts);
        },
      ]);
    } catch (e) {
      completer.completeError(e);
    }
    return completer.future;
  }
 List<LatLng> _sampleRoute(List<LatLng> route, int count) {    if (route.isEmpty) return [];
    final step = (route.length / count).ceil();
    final safeStep = step <= 0 ? 1 : step;
    final result = <LatLng>[];
    for (int i = 0; i < route.length; i += safeStep) {
      result.add(route[i]);
    }
    if (result.isEmpty || result.last != route.last) {
      result.add(route.last);
    }
    return result;
  }

  Set<String> _buildTargetTypes() {
    final Map<String, List<String>> filterMapping = {
      '買い物さんぽ': ['shopping_mall', 'store'],
      'グルメ\nさんぽ': ['restaurant', 'food'],
      '甘味\nさんぽ': ['cafe', 'bakery'],
      'ゆる\nさんぽ': ['park', 'tourist_attraction'],
    };
    final Set<String> targetTypes = {};
    for (final filter in widget.filters) {
      if (filterMapping.containsKey(filter)) {
        targetTypes.addAll(filterMapping[filter]!);
      }
    }
    return targetTypes;
  }

  void _loadPlacesAlongRouteWeb(List<LatLng> points) {
    final google = js.context['google'];
    if (google == null) {
      return;
    }
    final maps = (google as js.JsObject)['maps'];
    if (maps == null) {
      return;
    }
    final placesNs = maps['places'];
    if (placesNs == null) {
      return;
    }
    final serviceCtor = placesNs['PlacesService'];
    if (serviceCtor == null) {
      return;
    }
    final container = html.DivElement();
    final service = js.JsObject(serviceCtor as js.JsFunction, [container]);
    final targetTypes = _buildTargetTypes();
    if (targetTypes.isEmpty) {
      return;
    }
    for (final p in points) {
      for (final type in targetTypes) {
        final location = js.JsObject.jsify({
          'lat': p.latitude,
          'lng': p.longitude,
        });
        final request = js.JsObject.jsify({
          'location': location,
          'radius': 300,
          'type': type,
          'openNow': true,
        });
        service.callMethod('nearbySearch', [
          request,
          (results, status, [pagination]) {
            if (status != 'OK') {
              return;
            }
            if (results == null || !mounted) {
              return;
            }
            final list = results as List;
            if (list.isEmpty) {
              return;
            }
            final newMarkers = <Marker>{};
            for (var i = 0; i < list.length; i++) {
              final place = list[i] as js.JsObject;
              final ratingValue = place['rating'];
              final rating = ratingValue is num ? ratingValue.toDouble() : 0.0;
              if (rating < 3.0) {
                continue;
              }
              final geometry = place['geometry'];
              if (geometry == null) {
                continue;
              }
              final loc = geometry['location'] as js.JsObject?;
              if (loc == null) {
                continue;
              }
              final lat = loc.callMethod('lat') as num;
              final lng = loc.callMethod('lng') as num;
              final idValue = place['place_id'];
              final nameValue = place['name'];
              final id =
                  idValue != null ? idValue.toString() : '${lat}_${lng}_$type';
              final name = nameValue != null ? nameValue.toString() : '';
              newMarkers.add(
                Marker(
                  markerId: MarkerId(id),
                  position: LatLng(lat.toDouble(), lng.toDouble()),
                  infoWindow: InfoWindow(
                    title: name,
                    snippet: '⭐$rating ($type)',
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    type == 'park'
                        ? BitmapDescriptor.hueGreen
                        : BitmapDescriptor.hueRed,
                  ),
                ),
              );
            }
            if (newMarkers.isEmpty || !mounted) {
              return;
            }
            setState(() {
              _markers.addAll(newMarkers);
            });
          },
        ]);
      }
    }
  }

  Future<void> _getPlacesAlongRoute(List<LatLng> points) async {
    final targetTypes = _buildTargetTypes();
    if (targetTypes.isEmpty) return;

    for (final p in points) {
      for (final type in targetTypes) {
         final url =
            'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
            '?location=${p.latitude},${p.longitude}'
            '&radius=300' // 搜索半径 300 米
            '&type=$type'
            '&opennow=true'
            '&key=$_apiKey';

        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
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
