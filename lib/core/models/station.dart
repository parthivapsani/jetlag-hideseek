import 'package:freezed_annotation/freezed_annotation.dart';

part 'station.freezed.dart';
part 'station.g.dart';

/// A transit station/stop
@freezed
class Station with _$Station {
  const Station._();

  const factory Station({
    required String id,
    required String name,
    required double latitude,
    required double longitude,

    /// Transit system (e.g., "subway", "bus", "rail")
    String? transitType,

    /// Lines/routes that stop here (e.g., ["A", "C", "E"])
    @Default([]) List<String> lines,

    /// Specific services that stop here (for express/local distinction)
    /// e.g., ["A-express", "A-local", "C-local"]
    @Default([]) List<String> services,

    /// Parent station ID (for stations with multiple platforms)
    String? parentStationId,

    /// Accessibility info
    @Default(false) bool wheelchairAccessible,
  }) = _Station;

  factory Station.fromJson(Map<String, dynamic> json) => _$StationFromJson(json);

  /// Distance to a point in meters (haversine)
  double distanceTo(double lat, double lng) {
    const earthRadius = 6371000.0; // meters
    final dLat = _toRadians(lat - latitude);
    final dLng = _toRadians(lng - longitude);
    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(latitude)) *
            _cos(_toRadians(lat)) *
            _sin(dLng / 2) *
            _sin(dLng / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double deg) => deg * 3.141592653589793 / 180;
  static double _sin(double x) => x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  static double _cos(double x) => 1 - (x * x) / 2 + (x * x * x * x) / 24;
  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
  static double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 3.141592653589793 / 2;
    if (x == 0 && y < 0) return -3.141592653589793 / 2;
    return 0;
  }
  static double _atan(double x) => x - (x * x * x) / 3 + (x * x * x * x * x) / 5;
}

/// A transit line/route
@freezed
class TransitLine with _$TransitLine {
  const factory TransitLine({
    required String id,
    required String name,

    /// Short name (e.g., "A" for A train)
    String? shortName,

    /// Color for display
    String? color,

    /// Transit type
    String? transitType,

    /// All station IDs on this line
    @Default([]) List<String> stationIds,

    /// Service patterns (e.g., "express" skips certain stations)
    @Default({}) Map<String, List<String>> servicePatterns,
  }) = _TransitLine;

  factory TransitLine.fromJson(Map<String, dynamic> json) =>
      _$TransitLineFromJson(json);
}

/// Result of a station query
@freezed
class StationQueryResult with _$StationQueryResult {
  const factory StationQueryResult({
    /// Stations included in the query area
    required List<Station> includedStations,

    /// Stations excluded (outside query area but within squish boundary)
    required List<Station> uncertainStations,

    /// All stations in the broader area for context
    required List<Station> allNearbyStations,
  }) = _StationQueryResult;
}
