import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/station.dart';

/// Google Places API service for loading POIs
class PlacesService {
  final String? _apiKey;
  final Map<String, List<Station>> _cache = {};

  PlacesService({String? apiKey}) : _apiKey = apiKey;

  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  /// Search for transit stations near a location
  Future<List<Station>> searchTransitStations({
    required double lat,
    required double lng,
    double radiusMeters = 2000,
  }) async {
    return _searchPlaces(
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      type: 'transit_station',
    );
  }

  /// Search for subway stations near a location
  Future<List<Station>> searchSubwayStations({
    required double lat,
    required double lng,
    double radiusMeters = 2000,
  }) async {
    return _searchPlaces(
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      type: 'subway_station',
    );
  }

  /// Search for a specific place type
  Future<List<Station>> searchPlaceType({
    required double lat,
    required double lng,
    required String placeType,
    double radiusMeters = 2000,
  }) async {
    return _searchPlaces(
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      type: placeType,
    );
  }

  /// Search for places by keyword
  Future<List<Station>> searchByKeyword({
    required double lat,
    required double lng,
    required String keyword,
    double radiusMeters = 2000,
  }) async {
    return _searchPlaces(
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      keyword: keyword,
    );
  }

  Future<List<Station>> _searchPlaces({
    required double lat,
    required double lng,
    required double radiusMeters,
    String? type,
    String? keyword,
  }) async {
    if (!isConfigured) {
      debugPrint('⚠️ Places API not configured');
      return [];
    }

    // Check cache
    final cacheKey = '$lat,$lng,$radiusMeters,$type,$keyword';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final params = <String, String>{
        'location': '$lat,$lng',
        'radius': radiusMeters.round().toString(),
        'key': _apiKey!,
      };

      if (type != null) {
        params['type'] = type;
      }
      if (keyword != null) {
        params['keyword'] = keyword;
      }

      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/nearbysearch/json',
        params,
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        debugPrint('Places API error: ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];

      final stations = results.map((place) {
        final location = place['geometry']['location'];
        return Station(
          id: place['place_id'] as String,
          name: place['name'] as String,
          latitude: (location['lat'] as num).toDouble(),
          longitude: (location['lng'] as num).toDouble(),
          transitType: _inferTransitType(place['types'] as List<dynamic>?),
        );
      }).toList();

      // Cache result
      _cache[cacheKey] = stations;

      return stations;
    } catch (e) {
      debugPrint('Places API error: $e');
      return [];
    }
  }

  String? _inferTransitType(List<dynamic>? types) {
    if (types == null) return null;
    if (types.contains('subway_station')) return 'subway';
    if (types.contains('train_station')) return 'rail';
    if (types.contains('bus_station')) return 'bus';
    if (types.contains('transit_station')) return 'transit';
    return null;
  }

  /// Get place details by ID
  Future<Station?> getPlaceDetails(String placeId) async {
    if (!isConfigured) return null;

    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        {
          'place_id': placeId,
          'fields': 'name,geometry,types',
          'key': _apiKey!,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final result = data['result'] as Map<String, dynamic>?;

      if (result == null) return null;

      final location = result['geometry']['location'];
      return Station(
        id: placeId,
        name: result['name'] as String,
        latitude: (location['lat'] as num).toDouble(),
        longitude: (location['lng'] as num).toDouble(),
        transitType: _inferTransitType(result['types'] as List<dynamic>?),
      );
    } catch (e) {
      debugPrint('Place details error: $e');
      return null;
    }
  }

  /// Clear cache
  void clearCache() {
    _cache.clear();
  }
}

/// Provider for Places service
final placesServiceProvider = Provider<PlacesService>((ref) {
  // TODO: Get API key from environment or secure storage
  const apiKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');
  return PlacesService(apiKey: apiKey.isNotEmpty ? apiKey : null);
});

/// Provider for nearby transit stations
final nearbyTransitStationsProvider = FutureProvider.family<List<Station>, ({double lat, double lng, double radius})>(
  (ref, params) async {
    final service = ref.watch(placesServiceProvider);
    return service.searchTransitStations(
      lat: params.lat,
      lng: params.lng,
      radiusMeters: params.radius,
    );
  },
);

/// Common place types for game queries
class PlaceTypes {
  static const String transitStation = 'transit_station';
  static const String subwayStation = 'subway_station';
  static const String trainStation = 'train_station';
  static const String busStation = 'bus_station';
  static const String airport = 'airport';
  static const String museum = 'museum';
  static const String library = 'library';
  static const String park = 'park';
  static const String aquarium = 'aquarium';
  static const String zoo = 'zoo';
  static const String stadium = 'stadium';
  static const String hospital = 'hospital';
  static const String university = 'university';
  static const String church = 'church';
  static const String mosque = 'mosque';
  static const String synagogue = 'synagogue';
  static const String restaurant = 'restaurant';
  static const String cafe = 'cafe';
  static const String bar = 'bar';
  static const String supermarket = 'supermarket';
  static const String shoppingMall = 'shopping_mall';
  static const String movieTheater = 'movie_theater';
}
