import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/models/game_area.dart';

/// Controller for managing polygon editing operations
class PolygonEditorController extends ChangeNotifier {
  List<PolygonData> _inclusionPolygons = [];
  List<PolygonData> _exclusionPolygons = [];
  String? _activePolygonId;
  int? _selectedVertexIndex;
  final List<_PolygonSnapshot> _history = [];
  int _historyIndex = -1;

  List<PolygonData> get inclusionPolygons => _inclusionPolygons;
  List<PolygonData> get exclusionPolygons => _exclusionPolygons;
  String? get activePolygonId => _activePolygonId;
  int? get selectedVertexIndex => _selectedVertexIndex;

  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _history.length - 1;

  void _saveState() {
    // Remove any future states if we've undone
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }

    _history.add(_PolygonSnapshot(
      inclusionPolygons: List.from(_inclusionPolygons),
      exclusionPolygons: List.from(_exclusionPolygons),
    ));
    _historyIndex = _history.length - 1;

    // Limit history size
    if (_history.length > 50) {
      _history.removeAt(0);
      _historyIndex--;
    }
  }

  void undo() {
    if (!canUndo) return;
    _historyIndex--;
    final snapshot = _history[_historyIndex];
    _inclusionPolygons = List.from(snapshot.inclusionPolygons);
    _exclusionPolygons = List.from(snapshot.exclusionPolygons);
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _historyIndex++;
    final snapshot = _history[_historyIndex];
    _inclusionPolygons = List.from(snapshot.inclusionPolygons);
    _exclusionPolygons = List.from(snapshot.exclusionPolygons);
    notifyListeners();
  }

  void addPolygon(PolygonData polygon) {
    _saveState();
    if (polygon.isExclusion) {
      _exclusionPolygons = [..._exclusionPolygons, polygon];
    } else {
      _inclusionPolygons = [..._inclusionPolygons, polygon];
    }
    _activePolygonId = polygon.id;
    notifyListeners();
  }

  void addVertex(LatLng position, {required bool isExclusion}) {
    final targetPolygons = isExclusion ? _exclusionPolygons : _inclusionPolygons;

    if (_activePolygonId == null ||
        !targetPolygons.any((p) => p.id == _activePolygonId)) {
      // Create new polygon
      final newPolygon = PolygonData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        points: [LatLngData.fromLatLng(position)],
        isExclusion: isExclusion,
      );
      addPolygon(newPolygon);
    } else {
      // Add to existing polygon
      _saveState();
      final index = targetPolygons.indexWhere((p) => p.id == _activePolygonId);
      if (index != -1) {
        final polygon = targetPolygons[index];
        final updated = polygon.copyWith(
          points: [...polygon.points, LatLngData.fromLatLng(position)],
        );
        if (isExclusion) {
          _exclusionPolygons = [..._exclusionPolygons];
          _exclusionPolygons[index] = updated;
        } else {
          _inclusionPolygons = [..._inclusionPolygons];
          _inclusionPolygons[index] = updated;
        }
      }
      notifyListeners();
    }
  }

  void moveVertex(String polygonId, int vertexIndex, LatLng newPosition) {
    _saveState();
    final isExclusion = _exclusionPolygons.any((p) => p.id == polygonId);
    final polygons = isExclusion ? _exclusionPolygons : _inclusionPolygons;

    final index = polygons.indexWhere((p) => p.id == polygonId);
    if (index != -1) {
      final polygon = polygons[index];
      final newPoints = List<LatLngData>.from(polygon.points);
      newPoints[vertexIndex] = LatLngData.fromLatLng(newPosition);
      final updated = polygon.copyWith(points: newPoints);

      if (isExclusion) {
        _exclusionPolygons = [..._exclusionPolygons];
        _exclusionPolygons[index] = updated;
      } else {
        _inclusionPolygons = [..._inclusionPolygons];
        _inclusionPolygons[index] = updated;
      }
    }
    notifyListeners();
  }

  void deleteVertex(String polygonId, int vertexIndex) {
    _saveState();
    final isExclusion = _exclusionPolygons.any((p) => p.id == polygonId);
    final polygons = isExclusion ? _exclusionPolygons : _inclusionPolygons;

    final index = polygons.indexWhere((p) => p.id == polygonId);
    if (index != -1) {
      final polygon = polygons[index];
      if (polygon.points.length <= 3) {
        // Remove entire polygon
        if (isExclusion) {
          _exclusionPolygons = _exclusionPolygons
              .where((p) => p.id != polygonId)
              .toList();
        } else {
          _inclusionPolygons = _inclusionPolygons
              .where((p) => p.id != polygonId)
              .toList();
        }
        if (_activePolygonId == polygonId) {
          _activePolygonId = null;
        }
      } else {
        final newPoints = List<LatLngData>.from(polygon.points)
          ..removeAt(vertexIndex);
        final updated = polygon.copyWith(points: newPoints);

        if (isExclusion) {
          _exclusionPolygons = [..._exclusionPolygons];
          _exclusionPolygons[index] = updated;
        } else {
          _inclusionPolygons = [..._inclusionPolygons];
          _inclusionPolygons[index] = updated;
        }
      }
    }
    _selectedVertexIndex = null;
    notifyListeners();
  }

  void deletePolygon(String polygonId) {
    _saveState();
    _inclusionPolygons = _inclusionPolygons
        .where((p) => p.id != polygonId)
        .toList();
    _exclusionPolygons = _exclusionPolygons
        .where((p) => p.id != polygonId)
        .toList();
    if (_activePolygonId == polygonId) {
      _activePolygonId = null;
    }
    notifyListeners();
  }

  void selectPolygon(String? polygonId) {
    _activePolygonId = polygonId;
    _selectedVertexIndex = null;
    notifyListeners();
  }

  void selectVertex(String polygonId, int vertexIndex) {
    _activePolygonId = polygonId;
    _selectedVertexIndex = vertexIndex;
    notifyListeners();
  }

  void finishPolygon() {
    _activePolygonId = null;
    _selectedVertexIndex = null;
    notifyListeners();
  }

  void clear() {
    _saveState();
    _inclusionPolygons = [];
    _exclusionPolygons = [];
    _activePolygonId = null;
    _selectedVertexIndex = null;
    notifyListeners();
  }

  void setPolygons({
    List<PolygonData>? inclusion,
    List<PolygonData>? exclusion,
  }) {
    _saveState();
    if (inclusion != null) _inclusionPolygons = inclusion;
    if (exclusion != null) _exclusionPolygons = exclusion;
    notifyListeners();
  }

  /// Insert a vertex on an edge
  void insertVertexOnEdge(String polygonId, int afterIndex, LatLng position) {
    _saveState();
    final isExclusion = _exclusionPolygons.any((p) => p.id == polygonId);
    final polygons = isExclusion ? _exclusionPolygons : _inclusionPolygons;

    final index = polygons.indexWhere((p) => p.id == polygonId);
    if (index != -1) {
      final polygon = polygons[index];
      final newPoints = List<LatLngData>.from(polygon.points);
      newPoints.insert(afterIndex + 1, LatLngData.fromLatLng(position));
      final updated = polygon.copyWith(points: newPoints);

      if (isExclusion) {
        _exclusionPolygons = [..._exclusionPolygons];
        _exclusionPolygons[index] = updated;
      } else {
        _inclusionPolygons = [..._inclusionPolygons];
        _inclusionPolygons[index] = updated;
      }
    }
    notifyListeners();
  }
}

class _PolygonSnapshot {
  final List<PolygonData> inclusionPolygons;
  final List<PolygonData> exclusionPolygons;

  _PolygonSnapshot({
    required this.inclusionPolygons,
    required this.exclusionPolygons,
  });
}
