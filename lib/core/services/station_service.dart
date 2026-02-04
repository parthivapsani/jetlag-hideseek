import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/station.dart';

/// Service for managing transit stations
class StationService {
  /// In-memory station cache
  final Map<String, Station> _stations = {};
  final Map<String, TransitLine> _lines = {};

  /// Load stations for a region (would fetch from API/local DB in production)
  Future<void> loadStationsForRegion({
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
  }) async {
    // TODO: Implement actual data loading from:
    // 1. GTFS static feeds
    // 2. Google Places API
    // 3. Local bundled data
    // For now, this is a placeholder
  }

  /// Get all loaded stations
  List<Station> getAllStations() => _stations.values.toList();

  /// Get all loaded lines
  List<TransitLine> getAllLines() => _lines.values.toList();

  /// Find stations within a radius of a point
  List<Station> findStationsWithinRadius({
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
  }) {
    return _stations.values.where((station) {
      final distance = _haversineDistance(
        centerLat, centerLng,
        station.latitude, station.longitude,
      );
      return distance <= radiusMeters;
    }).toList();
  }

  /// Find stations on a specific line
  List<Station> findStationsOnLine(String lineId) {
    final line = _lines[lineId];
    if (line == null) return [];

    return line.stationIds
        .map((id) => _stations[id])
        .whereType<Station>()
        .toList();
  }

  /// Find stations on a specific service pattern (e.g., "A-express")
  List<Station> findStationsOnService(String lineId, String servicePattern) {
    final line = _lines[lineId];
    if (line == null) return [];

    final stationIds = line.servicePatterns[servicePattern];
    if (stationIds == null) {
      // Fall back to all stations on line
      return findStationsOnLine(lineId);
    }

    return stationIds
        .map((id) => _stations[id])
        .whereType<Station>()
        .toList();
  }

  /// Find the closest station to a point
  Station? findClosestStation({
    required double lat,
    required double lng,
    List<String>? filterLines,
    List<String>? filterServices,
  }) {
    var candidates = _stations.values.toList();

    // Filter by lines if specified
    if (filterLines != null && filterLines.isNotEmpty) {
      candidates = candidates.where((s) =>
        s.lines.any((line) => filterLines.contains(line))
      ).toList();
    }

    // Filter by services if specified
    if (filterServices != null && filterServices.isNotEmpty) {
      candidates = candidates.where((s) =>
        s.services.any((svc) => filterServices.contains(svc))
      ).toList();
    }

    if (candidates.isEmpty) return null;

    Station? closest;
    double closestDistance = double.infinity;

    for (final station in candidates) {
      final distance = _haversineDistance(lat, lng, station.latitude, station.longitude);
      if (distance < closestDistance) {
        closestDistance = distance;
        closest = station;
      }
    }

    return closest;
  }

  /// Query stations for a question area
  /// Returns stations definitely included, uncertain (in squish zone), and all nearby
  StationQueryResult queryStationsForQuestion({
    required double centerLat,
    required double centerLng,
    required double questionRadiusMeters,
    required double squishRadiusMeters,
    List<String>? filterLines,
  }) {
    final innerRadius = questionRadiusMeters;
    final outerRadius = questionRadiusMeters + squishRadiusMeters;

    final allNearby = <Station>[];
    final included = <Station>[];
    final uncertain = <Station>[];

    for (final station in _stations.values) {
      // Filter by lines if specified
      if (filterLines != null && filterLines.isNotEmpty) {
        if (!station.lines.any((line) => filterLines.contains(line))) {
          continue;
        }
      }

      final distance = _haversineDistance(
        centerLat, centerLng,
        station.latitude, station.longitude,
      );

      if (distance <= outerRadius * 1.5) {
        allNearby.add(station);
      }

      if (distance <= innerRadius) {
        included.add(station);
      } else if (distance <= outerRadius) {
        uncertain.add(station);
      }
    }

    return StationQueryResult(
      includedStations: included,
      uncertainStations: uncertain,
      allNearbyStations: allNearby,
    );
  }

  /// Add a station (for testing or manual entry)
  void addStation(Station station) {
    _stations[station.id] = station;
  }

  /// Add a line (for testing or manual entry)
  void addLine(TransitLine line) {
    _lines[line.id] = line;
  }

  /// Clear all data
  void clear() {
    _stations.clear();
    _lines.clear();
  }

  /// Haversine distance in meters
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0; // meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double deg) => deg * math.pi / 180;
}

/// Provider for station service
final stationServiceProvider = Provider<StationService>((ref) {
  return StationService();
});

/// Provider for stations within current view
final nearbyStationsProvider = FutureProvider.family<List<Station>, ({double lat, double lng, double radius})>(
  (ref, params) async {
    final service = ref.watch(stationServiceProvider);
    return service.findStationsWithinRadius(
      centerLat: params.lat,
      centerLng: params.lng,
      radiusMeters: params.radius,
    );
  },
);
