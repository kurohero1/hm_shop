import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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
  final void Function(LatLng origin, LatLng destination)? onRouteEndpointsChanged;

  const WalkMapWidget({
    super.key,
    required this.origin,
    required this.destination,
    this.waypoint,
    required this.filters,
    this.onRouteEndpointsChanged,
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
  String? _routeDistance;
  String? _routeDuration;

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

  bool _hasShownNoResultToast = false;

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
        _routeDistance = null;
        _routeDuration = null;
        _hasShownNoResultToast = false; // Reset toast flag
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
        _errorMessage = 'API キーが設定されていません。';
      });
      return;
    }
    try {
      final route = await _getRoute();
      // 如果没有路线，直接返回
      if (route.isEmpty) {
        setState(() {
          _loading = false;
          _errorMessage = 'ルートが見つかりませんでした。';
        });
        return;
      }

      if (mounted) {
        if (widget.onRouteEndpointsChanged != null) {
          final originPoint = route.first;
          final destinationPoint = route.last;
          widget.onRouteEndpointsChanged!(originPoint, destinationPoint);
        }
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
        await _loadPlacesAlongRouteWeb(sampled);
      } else {
        Future(() async {
          await _getPlacesAlongRoute(sampled, route);
          if (mounted) {
            setState(() {});
          }
        });
      }
      
      // Check if markers found
      if (mounted && _markers.isEmpty && !_hasShownNoResultToast && widget.filters.isNotEmpty) {
        _hasShownNoResultToast = true;
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('お探しの条件では経路周辺に該当する${widget.filters.join('、 ')}が見つかりませんでした。ルートのみ表示します。'),
             duration: const Duration(seconds: 4),
           ),
        );
      }

    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = '読み込みに失敗しました。';
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
      'language': 'ja',
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

    // Get distance and duration from the first leg (or sum if multiple legs)
    if (data['routes'].isNotEmpty && data['routes'][0]['legs'].isNotEmpty) {
       final legs = data['routes'][0]['legs'] as List;
       int totalMeters = 0;
       int totalSeconds = 0;
       for (final leg in legs) {
         totalMeters += (leg['distance']['value'] as num).toInt();
         totalSeconds += (leg['duration']['value'] as num).toInt();
       }
       
       // Format distance
       String distText;
       if (totalMeters >= 1000) {
         distText = '${(totalMeters / 1000).toStringAsFixed(1)} km';
       } else {
         distText = '$totalMeters m';
       }

       // Format duration
       String durText;
       if (totalSeconds >= 3600) {
         final hours = totalSeconds ~/ 3600;
         final mins = (totalSeconds % 3600) ~/ 60;
         durText = '$hours時間$mins分';
       } else {
         final mins = totalSeconds ~/ 60;
         durText = '$mins分';
       }

       if (mounted) {
         setState(() {
           _routeDistance = distText;
           _routeDuration = durText;
         });
       }
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
          
          // JS API: Extract distance and duration
          try {
            final legs = route0['legs'] as List;
            int totalMeters = 0;
            int totalSeconds = 0;
            for (var i = 0; i < legs.length; i++) {
              final leg = legs[i] as js.JsObject;
              final distVal = leg['distance']['value'] as num;
              final durVal = leg['duration']['value'] as num;
              totalMeters += distVal.toInt();
              totalSeconds += durVal.toInt();
            }

            String distText;
            if (totalMeters >= 1000) {
              distText = '${(totalMeters / 1000).toStringAsFixed(1)} km';
            } else {
              distText = '$totalMeters m';
            }

            String durText;
            if (totalSeconds >= 3600) {
              final hours = totalSeconds ~/ 3600;
              final mins = (totalSeconds % 3600) ~/ 60;
              durText = '$hours時間$mins分';
            } else {
              final mins = totalSeconds ~/ 60;
              durText = '$mins分';
            }

            if (mounted) {
              setState(() {
                _routeDistance = distText;
                _routeDuration = durText;
              });
            }
          } catch (e) {
            debugPrint('Error parsing JS directions result: $e');
          }

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

  int? _distanceMeters() {
    if (widget.filters.contains('30m以内')) return 30;
    if (widget.filters.contains('50m以内')) return 50;
    return null;
  }

  Set<String> _buildTargetTypes() {
    final Map<String, List<String>> filterMapping = {
      '買い物さんぽ': ['shopping_mall', 'store'],
      'グルメ\nさんぽ': ['restaurant', 'cafe'],
      '甘味\nさんぽ': ['cafe', 'bakery'],
      'ゆる\nさんぽ': ['park', 'tourist_attraction'],
    };
    final Set<String> targetTypes = {};
    
    // 1. Check for specific "Sanpo" filters
    for (final filter in widget.filters) {
      if (filterMapping.containsKey(filter)) {
        targetTypes.addAll(filterMapping[filter]!);
      }
    }

    // 2. Check for "Conbini" mode
    if (widget.filters.contains('コンビニのみ')) {
      targetTypes.add('convenience_store');
    }

    // 3. Check for "High Rating" or "Cheap" mode
    // If no other types are selected, default to restaurant
    if ((widget.filters.contains('高評価重視') || widget.filters.contains('リーズナブル重視')) && targetTypes.isEmpty) {
      targetTypes.add('restaurant');
    }

    return targetTypes;
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Earth radius in meters
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dphi = (lat2 - lat1) * math.pi / 180;
    final dlambda = (lon2 - lon1) * math.pi / 180;
    final a = math.pow(math.sin(dphi / 2), 2) +
        math.cos(phi1) * math.cos(phi2) * math.pow(math.sin(dlambda / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  bool _isWithinRoute(double lat, double lng, List<LatLng> route, double maxMeters) {
    // Optimize: Check bounding box first? Or just iterate.
    // Given the number of points might be large, maybe sample the route for this check or just iterate.
    // map.py iterates all.
    for (final p in route) {
      if (_haversine(lat, lng, p.latitude, p.longitude) <= maxMeters) {
        return true;
      }
    }
    return false;
  }

  bool _matchBrand(String name) {
    // If no brand filter is selected, return true (unless we are in conbini mode and specific brands are not selected?)
    // Logic: If "Conbini" is selected, check if any Brand filter is ALSO selected.
    // If "Conbini" is selected but NO brand filter, return true (All).
    // If "Conbini" is selected AND brand filters exist, match against them.
    
    final brands = ['セブン', 'ファミマ', 'ローソン'];
    final selectedBrands = widget.filters.where((f) => brands.contains(f)).toSet();

    if (selectedBrands.isEmpty) return true; // "All" or no brand preference

    final nameJp = name;
    final nameEn = name.toLowerCase();

    if (selectedBrands.contains('セブン')) {
      if (nameJp.contains('セブン') || nameJp.contains('7-') || nameEn.contains('7-eleven')) return true;
    }
    if (selectedBrands.contains('ファミマ')) {
      if (nameJp.contains('ファミリーマート') || nameEn.contains('familymart')) return true;
    }
    if (selectedBrands.contains('ローソン')) {
      if (nameJp.contains('ローソン') || nameEn.contains('lawson')) return true;
    }

    return false;
  }

  Future<void> _loadPlacesAlongRouteWeb(List<LatLng> points) async {
    final completer = Completer<void>();
    final google = js.context['google'];
    if (google == null) {
      completer.complete();
      return completer.future;
    }
    final maps = (google as js.JsObject)['maps'];
    if (maps == null) {
      completer.complete();
      return completer.future;
    }
    final placesNs = maps['places'];
    if (placesNs == null) {
      completer.complete();
      return completer.future;
    }
    final serviceCtor = placesNs['PlacesService'];
    if (serviceCtor == null) {
      completer.complete();
      return completer.future;
    }
    final container = html.DivElement();
    final service = js.JsObject(serviceCtor as js.JsFunction, [container]);
    final targetTypes = _buildTargetTypes();
    if (targetTypes.isEmpty) {
      completer.complete();
      return completer.future;
    }

    int pendingRequests = points.length * targetTypes.length;
    if (pendingRequests == 0) {
      completer.complete();
      return completer.future;
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
            pendingRequests--;
            
            if (status == 'OK' && results != null && mounted) {
                final list = results as List;
                if (list.isNotEmpty) {
                    final newMarkers = <Marker>{};
                    for (var i = 0; i < list.length; i++) {
                      // ... (existing marker logic)
                      final place = list[i] as js.JsObject;
                      final ratingValue = place['rating'];
                      final rating = ratingValue is num ? ratingValue.toDouble() : 0.0;
                      final priceValue = place['price_level'];
                      final price = priceValue is num ? priceValue.toInt() : 0;
                      
                      // Filter Logic (Web)
                      bool pass = false;
                      if (widget.filters.contains('コンビニのみ')) {
                         final nameValue = place['name'];
                         final name = nameValue != null ? nameValue.toString() : '';
                         if (_matchBrand(name)) pass = true;
                      } else if (widget.filters.contains('高評価重視')) {
                         if (rating >= 4.2 && (price == 0 || price <= 4)) pass = true;
                      } else if (widget.filters.contains('リーズナブル重視')) {
                         if (price <= 2) pass = true;
                      } else {
                         if (rating >= 3.0) pass = true;
                      }
        
                      if (!pass) continue;
        
                      final geometry = place['geometry'];
                      if (geometry == null) continue;
                      
                      final loc = geometry['location'] as js.JsObject?;
                      if (loc == null) continue;
                      
                      final lat = loc.callMethod('lat') as num;
                      final lng = loc.callMethod('lng') as num;
                      final idValue = place['place_id'];
                      final nameValue = place['name'];
                      final id = idValue != null ? idValue.toString() : '${lat}_${lng}_$type';
                      final name = nameValue != null ? nameValue.toString() : '';
        
                      final distance = _distanceMeters();
                      if (distance != null &&
                          !_isWithinRoute(
                            lat.toDouble(),
                            lng.toDouble(),
                            points,
                            distance.toDouble(),
                          )) {
                        continue;
                      }
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
                    if (newMarkers.isNotEmpty && mounted) {
                      setState(() {
                        _markers.addAll(newMarkers);
                      });
                    }
                }
            }
            
            if (pendingRequests <= 0 && !completer.isCompleted) {
                completer.complete();
            }
          },
        ]);
      }
    }
    return completer.future;
  }

  Future<void> _getPlacesAlongRoute(List<LatLng> points, List<LatLng> fullRoute) async {
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
          final price = place['price_level'] ?? 0; // 0 表示未知
          final name = place['name'] ?? '';
          final lat = place['geometry']['location']['lat'];
          final lng = place['geometry']['location']['lng'];

          // Filter Logic based on map.py
          bool pass = false;
          if (widget.filters.contains('コンビニのみ')) {
            // Conbini: Check brand
            if (_matchBrand(name)) {
              pass = true;
            }
          } else if (widget.filters.contains('高評価重視')) {
            // High Rating: rating >= 4.2, price <= 4
            if (rating >= 4.2 && (price == 0 || price <= 4)) pass = true;
          } else if (widget.filters.contains('リーズナブル重視')) {
            // Cheap: price <= 2 (map.py: max_price=2)
            if (price <= 2) pass = true;
          } else {
            // Default behavior
            if (rating >= 3.0) pass = true;
          }

          if (!pass) continue;

          // Distance Logic when range filter is selected
          final distance = _distanceMeters();
          if (distance != null &&
              !_isWithinRoute(lat, lng, fullRoute, distance.toDouble())) {
            continue;
          }

          _markers.add(
            Marker(
              markerId: MarkerId(place['place_id']),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: name,
                snippet: '⭐$rating ($type)',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                type == 'park' ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
              ),
            ),
          );
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

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _center,
            zoom: 14,
          ),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          zoomControlsEnabled: false,
        ),
        if (_routeDistance != null && _routeDuration != null)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.directions_walk, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    '$_routeDistance  /  $_routeDuration',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
