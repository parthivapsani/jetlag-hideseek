import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

part 'game_area.freezed.dart';
part 'game_area.g.dart';

@freezed
class GameArea with _$GameArea {
  const factory GameArea({
    required String id,
    required String name,
    required List<PolygonData> inclusionPolygons,
    @Default([]) List<PolygonData> exclusionPolygons,
    required double centerLat,
    required double centerLng,
    @Default(12.0) double defaultZoom,
    String? createdBy,
    DateTime? createdAt,
  }) = _GameArea;

  factory GameArea.fromJson(Map<String, dynamic> json) =>
      _$GameAreaFromJson(json);
}

@freezed
class PolygonData with _$PolygonData {
  const factory PolygonData({
    required String id,
    required List<LatLngData> points,
    @Default(false) bool isExclusion,
  }) = _PolygonData;

  factory PolygonData.fromJson(Map<String, dynamic> json) =>
      _$PolygonDataFromJson(json);
}

@freezed
class LatLngData with _$LatLngData {
  const factory LatLngData({
    required double latitude,
    required double longitude,
  }) = _LatLngData;

  factory LatLngData.fromJson(Map<String, dynamic> json) =>
      _$LatLngDataFromJson(json);

  factory LatLngData.fromLatLng(LatLng latLng) => LatLngData(
        latitude: latLng.latitude,
        longitude: latLng.longitude,
      );
}

extension LatLngDataX on LatLngData {
  LatLng toLatLng() => LatLng(latitude, longitude);
}

extension PolygonDataX on PolygonData {
  List<LatLng> toLatLngList() => points.map((p) => p.toLatLng()).toList();
}
