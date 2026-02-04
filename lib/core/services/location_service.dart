import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/game_area.dart';

class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;

  Position? get lastPosition => _lastPosition;

  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<Position?> getCurrentPosition() async {
    if (!await checkPermission()) {
      return null;
    }

    try {
      _lastPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return _lastPosition;
    } catch (e) {
      return null;
    }
  }

  Stream<Position> getPositionStream({
    int distanceFilter = 10,
    Duration? interval,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    ).map((position) {
      _lastPosition = position;
      return position;
    });
  }

  void startTracking({
    required void Function(Position position) onPosition,
    int distanceFilter = 10,
  }) {
    _positionSubscription?.cancel();
    _positionSubscription = getPositionStream(
      distanceFilter: distanceFilter,
    ).listen(onPosition);
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  // ============ Distance Calculations ============

  /// Calculate distance between two points in meters
  double distanceBetween(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  /// Calculate distance in miles
  double distanceInMiles(LatLng from, LatLng to) {
    return distanceBetween(from, to) / 1609.344;
  }

  /// Calculate distance in feet
  double distanceInFeet(LatLng from, LatLng to) {
    return distanceBetween(from, to) * 3.28084;
  }

  // ============ Polygon Operations ============

  /// Check if a point is inside a polygon
  bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;

    int intersections = 0;
    for (int i = 0; i < polygon.length; i++) {
      final v1 = polygon[i];
      final v2 = polygon[(i + 1) % polygon.length];

      if (_rayIntersectsSegment(point, v1, v2)) {
        intersections++;
      }
    }

    return intersections.isOdd;
  }

  bool _rayIntersectsSegment(LatLng point, LatLng v1, LatLng v2) {
    if (v1.latitude > v2.latitude) {
      final temp = v1;
      v1 = v2;
      v2 = temp;
    }

    if (point.latitude == v1.latitude || point.latitude == v2.latitude) {
      point = LatLng(point.latitude + 0.00001, point.longitude);
    }

    if (point.latitude < v1.latitude || point.latitude > v2.latitude) {
      return false;
    }

    if (point.longitude >= math.max(v1.longitude, v2.longitude)) {
      return false;
    }

    if (point.longitude < math.min(v1.longitude, v2.longitude)) {
      return true;
    }

    final slope = (v2.longitude - v1.longitude) / (v2.latitude - v1.latitude);
    final intersectLng = v1.longitude + (point.latitude - v1.latitude) * slope;

    return point.longitude < intersectLng;
  }

  /// Check if point is in game area (inside inclusion, outside exclusion)
  bool isPointInGameArea(LatLng point, GameArea area) {
    // Must be inside at least one inclusion polygon
    bool inInclusion = false;
    for (final polygon in area.inclusionPolygons) {
      if (isPointInPolygon(point, polygon.toLatLngList())) {
        inInclusion = true;
        break;
      }
    }

    if (!inInclusion) return false;

    // Must not be inside any exclusion polygon
    for (final polygon in area.exclusionPolygons) {
      if (isPointInPolygon(point, polygon.toLatLngList())) {
        return false;
      }
    }

    return true;
  }

  /// Get the center of a polygon
  LatLng getPolygonCenter(List<LatLng> polygon) {
    if (polygon.isEmpty) return const LatLng(0, 0);

    double latSum = 0;
    double lngSum = 0;

    for (final point in polygon) {
      latSum += point.latitude;
      lngSum += point.longitude;
    }

    return LatLng(
      latSum / polygon.length,
      lngSum / polygon.length,
    );
  }

  /// Get bounding box of a polygon
  LatLngBounds getPolygonBounds(List<LatLng> polygon) {
    if (polygon.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(0, 0),
        northeast: const LatLng(0, 0),
      );
    }

    double minLat = polygon.first.latitude;
    double maxLat = polygon.first.latitude;
    double minLng = polygon.first.longitude;
    double maxLng = polygon.first.longitude;

    for (final point in polygon) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // ============ Circle Operations ============

  /// Check if point is within radius of center
  bool isPointInCircle(LatLng point, LatLng center, double radiusMeters) {
    return distanceBetween(point, center) <= radiusMeters;
  }

  /// Generate circle points for display
  List<LatLng> generateCirclePoints(
    LatLng center,
    double radiusMeters, {
    int points = 64,
  }) {
    final result = <LatLng>[];
    final radiusInDegrees = radiusMeters / 111320;

    for (int i = 0; i < points; i++) {
      final angle = (i * 360 / points) * math.pi / 180;
      final lat = center.latitude + radiusInDegrees * math.cos(angle);
      final lng = center.longitude +
          radiusInDegrees * math.sin(angle) /
              math.cos(center.latitude * math.pi / 180);
      result.add(LatLng(lat, lng));
    }

    return result;
  }

  // ============ Direction ============

  /// Get cardinal direction from one point to another
  String getCardinalDirection(LatLng from, LatLng to) {
    final bearing = Geolocator.bearingBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );

    if (bearing >= -22.5 && bearing < 22.5) return 'N';
    if (bearing >= 22.5 && bearing < 67.5) return 'NE';
    if (bearing >= 67.5 && bearing < 112.5) return 'E';
    if (bearing >= 112.5 && bearing < 157.5) return 'SE';
    if (bearing >= 157.5 || bearing < -157.5) return 'S';
    if (bearing >= -157.5 && bearing < -112.5) return 'SW';
    if (bearing >= -112.5 && bearing < -67.5) return 'W';
    return 'NW';
  }

  /// Is point north of reference?
  bool isNorthOf(LatLng point, LatLng reference) {
    return point.latitude > reference.latitude;
  }

  /// Is point east of reference?
  bool isEastOf(LatLng point, LatLng reference) {
    return point.longitude > reference.longitude;
  }

  void dispose() {
    stopTracking();
  }
}
