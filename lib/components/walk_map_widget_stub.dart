import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class WalkMapWidget extends StatelessWidget {
  final String origin;
  final String destination;
  final String? waypoint;
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
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: const Text(
        '地図は現在モバイル版では簡易表示です。\nWeb 版でより詳細な地図が表示されます。',
        textAlign: TextAlign.center,
      ),
    );
  }
}
