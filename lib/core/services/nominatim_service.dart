import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/game_area.dart';

/// Service for fetching geographic boundaries from OpenStreetMap Nominatim API
class NominatimService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'JetLagHideSeek/1.0';

  final http.Client _client;

  NominatimService({http.Client? client}) : _client = client ?? http.Client();

  /// Search for a place by name and return results
  Future<List<NominatimPlace>> search(String query, {int limit = 5}) async {
    final uri = Uri.parse('$_baseUrl/search').replace(
      queryParameters: {
        'q': query,
        'format': 'json',
        'limit': limit.toString(),
        'polygon_geojson': '1',
        'addressdetails': '1',
      },
    );

    final response = await _client.get(
      uri,
      headers: {'User-Agent': _userAgent},
    );

    if (response.statusCode != 200) {
      throw NominatimException('Search failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as List;
    return data.map((e) => NominatimPlace.fromJson(e)).toList();
  }

  /// Get detailed boundary for a specific OSM place
  Future<NominatimPlace?> getPlaceDetails(int osmId, String osmType) async {
    final uri = Uri.parse('$_baseUrl/details').replace(
      queryParameters: {
        'osmtype': osmType.substring(0, 1).toUpperCase(),
        'osmid': osmId.toString(),
        'polygon_geojson': '1',
        'format': 'json',
      },
    );

    final response = await _client.get(
      uri,
      headers: {'User-Agent': _userAgent},
    );

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body);
    return NominatimPlace.fromJson(data);
  }

  /// Search for a place and return its boundary as a polygon
  Future<List<LatLng>?> getPlaceBoundary(String query) async {
    final places = await search(query, limit: 1);
    if (places.isEmpty) return null;

    final place = places.first;
    return place.boundaryPolygon;
  }

  /// Reverse geocode a lat/lng to get place info
  Future<NominatimPlace?> reverseGeocode(double lat, double lng) async {
    final uri = Uri.parse('$_baseUrl/reverse').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lon': lng.toString(),
        'format': 'json',
        'addressdetails': '1',
      },
    );

    final response = await _client.get(
      uri,
      headers: {'User-Agent': _userAgent},
    );

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body);
    return NominatimPlace.fromJson(data);
  }

  void dispose() {
    _client.close();
  }
}

class NominatimPlace {
  final int? placeId;
  final int? osmId;
  final String? osmType;
  final String displayName;
  final String? type;
  final String? category;
  final double lat;
  final double lng;
  final Map<String, dynamic>? address;
  final Map<String, dynamic>? geojson;
  final List<double>? boundingBox;

  NominatimPlace({
    this.placeId,
    this.osmId,
    this.osmType,
    required this.displayName,
    this.type,
    this.category,
    required this.lat,
    required this.lng,
    this.address,
    this.geojson,
    this.boundingBox,
  });

  factory NominatimPlace.fromJson(Map<String, dynamic> json) {
    return NominatimPlace(
      placeId: json['place_id'] as int?,
      osmId: json['osm_id'] as int?,
      osmType: json['osm_type'] as String?,
      displayName: json['display_name'] ?? json['localname'] ?? '',
      type: json['type'] as String?,
      category: json['category'] as String?,
      lat: _parseDouble(json['lat']),
      lng: _parseDouble(json['lon']),
      address: json['address'] as Map<String, dynamic>?,
      geojson: json['geojson'] as Map<String, dynamic>?,
      boundingBox: (json['boundingbox'] as List?)
          ?.map((e) => double.parse(e.toString()))
          .toList(),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  LatLng get center => LatLng(lat, lng);

  /// Extract polygon boundary from GeoJSON
  List<LatLng>? get boundaryPolygon {
    if (geojson == null) return null;

    final type = geojson!['type'] as String?;
    final coordinates = geojson!['coordinates'];

    if (coordinates == null) return null;

    if (type == 'Polygon') {
      return _parsePolygonCoordinates(coordinates[0]);
    } else if (type == 'MultiPolygon') {
      // Return the largest polygon (first one typically)
      final polygons = coordinates as List;
      if (polygons.isEmpty) return null;
      return _parsePolygonCoordinates(polygons[0][0]);
    } else if (type == 'LineString') {
      return _parsePolygonCoordinates(coordinates);
    }

    return null;
  }

  /// Get all polygons for MultiPolygon
  List<List<LatLng>> get allBoundaryPolygons {
    if (geojson == null) return [];

    final type = geojson!['type'] as String?;
    final coordinates = geojson!['coordinates'];

    if (coordinates == null) return [];

    if (type == 'Polygon') {
      final polygon = _parsePolygonCoordinates(coordinates[0]);
      return polygon != null ? [polygon] : [];
    } else if (type == 'MultiPolygon') {
      final result = <List<LatLng>>[];
      for (final polygon in coordinates) {
        final parsed = _parsePolygonCoordinates(polygon[0]);
        if (parsed != null) result.add(parsed);
      }
      return result;
    }

    return [];
  }

  List<LatLng>? _parsePolygonCoordinates(List<dynamic> coords) {
    try {
      return coords.map((coord) {
        final c = coord as List;
        return LatLng(
          (c[1] as num).toDouble(),
          (c[0] as num).toDouble(),
        );
      }).toList();
    } catch (e) {
      return null;
    }
  }

  /// Convert to PolygonData for use in GameArea
  PolygonData? toPolygonData({bool isExclusion = false}) {
    final polygon = boundaryPolygon;
    if (polygon == null) return null;

    return PolygonData(
      id: 'nominatim_${osmType}_$osmId',
      points: polygon.map((p) => LatLngData.fromLatLng(p)).toList(),
      isExclusion: isExclusion,
    );
  }
}

class NominatimException implements Exception {
  final String message;
  NominatimException(this.message);

  @override
  String toString() => 'NominatimException: $message';
}
