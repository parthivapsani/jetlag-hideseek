import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/nominatim_service.dart';
import '../../app/theme.dart';
import 'widgets/polygon_editor_toolbar.dart';
import 'widgets/game_settings_sheet.dart';

enum EditorMode { view, addVertex, moveVertex, deleteVertex, exclusion }

class PolygonEditorScreen extends ConsumerStatefulWidget {
  const PolygonEditorScreen({super.key});

  @override
  ConsumerState<PolygonEditorScreen> createState() => _PolygonEditorScreenState();
}

class _PolygonEditorScreenState extends ConsumerState<PolygonEditorScreen> {
  GoogleMapController? _mapController;
  final _searchController = TextEditingController();

  EditorMode _mode = EditorMode.view;
  List<PolygonData> _inclusionPolygons = [];
  List<PolygonData> _exclusionPolygons = [];
  String? _selectedPolygonId;
  int? _selectedVertexIndex;

  LatLng _center = const LatLng(40.7128, -74.0060); // NYC default
  double _zoom = 12;
  String _areaName = '';

  bool _isSearching = false;
  List<NominatimPlace> _searchResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Define Game Area'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _canSave ? _showSettingsAndCreate : null,
            tooltip: 'Create game',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: _zoom),
            onMapCreated: (controller) => _mapController = controller,
            onTap: _onMapTap,
            onLongPress: _onMapLongPress,
            polygons: _buildPolygons(),
            markers: _buildMarkers(),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Search Bar
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search location (e.g., "Manhattan")',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchResults = []);
                                  },
                                )
                              : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: _searchLocation,
                  ),
                  if (_searchResults.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final place = _searchResults[index];
                          return ListTile(
                            title: Text(
                              place.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            dense: true,
                            onTap: () => _selectSearchResult(place),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Toolbar
          Positioned(
            bottom: 100,
            left: 8,
            child: PolygonEditorToolbar(
              mode: _mode,
              onModeChanged: (mode) => setState(() => _mode = mode),
              onUndo: _inclusionPolygons.isNotEmpty ? _undo : null,
              onClear: _inclusionPolygons.isNotEmpty ? _clearAll : null,
            ),
          ),

          // Instructions
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _getInstructions(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // My Location Button
          Positioned(
            bottom: 100,
            right: 8,
            child: FloatingActionButton.small(
              heroTag: 'myLocation',
              onPressed: _goToMyLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  String _getInstructions() {
    switch (_mode) {
      case EditorMode.view:
        return 'Search for a location or tap the pencil to start drawing';
      case EditorMode.addVertex:
        return 'Tap on the map to add points. Long-press to finish polygon.';
      case EditorMode.moveVertex:
        return 'Drag vertices to adjust the polygon';
      case EditorMode.deleteVertex:
        return 'Tap a vertex to delete it';
      case EditorMode.exclusion:
        return 'Draw areas to exclude from the game area';
    }
  }

  bool get _canSave => _inclusionPolygons.isNotEmpty &&
      _inclusionPolygons.any((p) => p.points.length >= 3);

  Set<Polygon> _buildPolygons() {
    final polygons = <Polygon>{};

    for (final polygon in _inclusionPolygons) {
      if (polygon.points.length >= 3) {
        polygons.add(Polygon(
          polygonId: PolygonId(polygon.id),
          points: polygon.toLatLngList(),
          fillColor: JetLagTheme.hiderGreen.withOpacity(0.3),
          strokeColor: JetLagTheme.hiderGreen,
          strokeWidth: 3,
          consumeTapEvents: true,
          onTap: () => _selectPolygon(polygon.id),
        ));
      }
    }

    for (final polygon in _exclusionPolygons) {
      if (polygon.points.length >= 3) {
        polygons.add(Polygon(
          polygonId: PolygonId(polygon.id),
          points: polygon.toLatLngList(),
          fillColor: JetLagTheme.seekerRed.withOpacity(0.3),
          strokeColor: JetLagTheme.seekerRed,
          strokeWidth: 3,
          consumeTapEvents: true,
          onTap: () => _selectPolygon(polygon.id),
        ));
      }
    }

    return polygons;
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // Add vertex markers when in edit mode
    if (_mode == EditorMode.moveVertex || _mode == EditorMode.deleteVertex) {
      final allPolygons = [..._inclusionPolygons, ..._exclusionPolygons];
      for (final polygon in allPolygons) {
        for (int i = 0; i < polygon.points.length; i++) {
          final point = polygon.points[i];
          final isSelected = polygon.id == _selectedPolygonId && i == _selectedVertexIndex;
          markers.add(Marker(
            markerId: MarkerId('${polygon.id}_$i'),
            position: point.toLatLng(),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isSelected ? BitmapDescriptor.hueBlue : BitmapDescriptor.hueRed,
            ),
            draggable: _mode == EditorMode.moveVertex,
            onDragEnd: (newPos) => _onVertexDragged(polygon.id, i, newPos),
            onTap: () => _onVertexTap(polygon.id, i),
          ));
        }
      }
    }

    return markers;
  }

  void _onMapTap(LatLng position) {
    if (_mode == EditorMode.addVertex) {
      _addVertex(position, isExclusion: false);
    } else if (_mode == EditorMode.exclusion) {
      _addVertex(position, isExclusion: true);
    }
  }

  void _onMapLongPress(LatLng position) {
    if (_mode == EditorMode.addVertex || _mode == EditorMode.exclusion) {
      // Finish current polygon
      setState(() => _mode = EditorMode.view);
    }
  }

  void _addVertex(LatLng position, {required bool isExclusion}) {
    setState(() {
      final polygons = isExclusion ? _exclusionPolygons : _inclusionPolygons;

      // Find or create active polygon
      PolygonData? activePolygon;
      if (polygons.isNotEmpty && _selectedPolygonId != null) {
        activePolygon = polygons.where((p) => p.id == _selectedPolygonId).firstOrNull;
      }

      if (activePolygon == null) {
        // Create new polygon
        final newPolygon = PolygonData(
          id: const Uuid().v4(),
          points: [LatLngData.fromLatLng(position)],
          isExclusion: isExclusion,
        );
        if (isExclusion) {
          _exclusionPolygons = [..._exclusionPolygons, newPolygon];
        } else {
          _inclusionPolygons = [..._inclusionPolygons, newPolygon];
        }
        _selectedPolygonId = newPolygon.id;
      } else {
        // Add point to existing polygon
        final updatedPolygon = activePolygon.copyWith(
          points: [...activePolygon.points, LatLngData.fromLatLng(position)],
        );
        if (isExclusion) {
          _exclusionPolygons = _exclusionPolygons
              .map((p) => p.id == activePolygon!.id ? updatedPolygon : p)
              .toList();
        } else {
          _inclusionPolygons = _inclusionPolygons
              .map((p) => p.id == activePolygon!.id ? updatedPolygon : p)
              .toList();
        }
      }
    });
  }

  void _selectPolygon(String polygonId) {
    setState(() {
      _selectedPolygonId = polygonId;
      _selectedVertexIndex = null;
    });
  }

  void _onVertexTap(String polygonId, int index) {
    if (_mode == EditorMode.deleteVertex) {
      _deleteVertex(polygonId, index);
    } else {
      setState(() {
        _selectedPolygonId = polygonId;
        _selectedVertexIndex = index;
      });
    }
  }

  void _onVertexDragged(String polygonId, int index, LatLng newPosition) {
    setState(() {
      final isExclusion = _exclusionPolygons.any((p) => p.id == polygonId);
      final polygons = isExclusion ? _exclusionPolygons : _inclusionPolygons;
      final polygon = polygons.firstWhere((p) => p.id == polygonId);

      final newPoints = List<LatLngData>.from(polygon.points);
      newPoints[index] = LatLngData.fromLatLng(newPosition);

      final updatedPolygon = polygon.copyWith(points: newPoints);

      if (isExclusion) {
        _exclusionPolygons = _exclusionPolygons
            .map((p) => p.id == polygonId ? updatedPolygon : p)
            .toList();
      } else {
        _inclusionPolygons = _inclusionPolygons
            .map((p) => p.id == polygonId ? updatedPolygon : p)
            .toList();
      }
    });
  }

  void _deleteVertex(String polygonId, int index) {
    setState(() {
      final isExclusion = _exclusionPolygons.any((p) => p.id == polygonId);
      final polygons = isExclusion ? _exclusionPolygons : _inclusionPolygons;
      final polygon = polygons.firstWhere((p) => p.id == polygonId);

      if (polygon.points.length <= 3) {
        // Remove entire polygon if too few points
        if (isExclusion) {
          _exclusionPolygons = _exclusionPolygons.where((p) => p.id != polygonId).toList();
        } else {
          _inclusionPolygons = _inclusionPolygons.where((p) => p.id != polygonId).toList();
        }
      } else {
        final newPoints = List<LatLngData>.from(polygon.points)..removeAt(index);
        final updatedPolygon = polygon.copyWith(points: newPoints);

        if (isExclusion) {
          _exclusionPolygons = _exclusionPolygons
              .map((p) => p.id == polygonId ? updatedPolygon : p)
              .toList();
        } else {
          _inclusionPolygons = _inclusionPolygons
              .map((p) => p.id == polygonId ? updatedPolygon : p)
              .toList();
        }
      }
    });
  }

  void _undo() {
    setState(() {
      if (_inclusionPolygons.isNotEmpty) {
        final lastPolygon = _inclusionPolygons.last;
        if (lastPolygon.points.length > 1) {
          _inclusionPolygons = [
            ..._inclusionPolygons.sublist(0, _inclusionPolygons.length - 1),
            lastPolygon.copyWith(
              points: lastPolygon.points.sublist(0, lastPolygon.points.length - 1),
            ),
          ];
        } else {
          _inclusionPolygons = _inclusionPolygons.sublist(0, _inclusionPolygons.length - 1);
        }
      }
    });
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All?'),
        content: const Text('This will remove all polygons. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _inclusionPolygons = [];
                _exclusionPolygons = [];
                _selectedPolygonId = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final nominatim = ref.read(nominatimServiceProvider);
      final results = await nominatim.search(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    }
  }

  void _selectSearchResult(NominatimPlace place) {
    setState(() {
      _searchResults = [];
      _searchController.clear();
      _areaName = place.displayName.split(',').first;
    });

    // Move map to location
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(place.center, 13),
    );

    // If place has boundary, use it
    final boundary = place.boundaryPolygon;
    if (boundary != null && boundary.length >= 3) {
      setState(() {
        _inclusionPolygons = [
          PolygonData(
            id: const Uuid().v4(),
            points: boundary.map((p) => LatLngData.fromLatLng(p)).toList(),
            isExclusion: false,
          ),
        ];
        _center = place.center;
      });
    } else {
      setState(() {
        _center = place.center;
      });
    }
  }

  Future<void> _goToMyLocation() async {
    final location = ref.read(locationServiceProvider);
    final position = await location.getCurrentPosition();
    if (position != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );
    }
  }

  Future<void> _showSettingsAndCreate() async {
    final name = _areaName.isEmpty ? 'Custom Area' : _areaName;

    final result = await showModalBottomSheet<GameSettings>(
      context: context,
      isScrollControlled: true,
      builder: (context) => GameSettingsSheet(areaName: name),
    );

    if (result != null) {
      await _createGame(result);
    }
  }

  Future<void> _createGame(GameSettings settings) async {
    try {
      // Calculate center
      final allPoints = _inclusionPolygons.expand((p) => p.points).toList();
      final centerLat = allPoints.map((p) => p.latitude).reduce((a, b) => a + b) / allPoints.length;
      final centerLng = allPoints.map((p) => p.longitude).reduce((a, b) => a + b) / allPoints.length;

      // Save game area
      final gameArea = GameArea(
        id: const Uuid().v4(),
        name: settings.areaName,
        inclusionPolygons: _inclusionPolygons,
        exclusionPolygons: _exclusionPolygons,
        centerLat: centerLat,
        centerLng: centerLng,
        defaultZoom: _zoom,
      );

      final savedArea = await ref.read(gameAreaActionsProvider).saveGameArea(gameArea);

      // Create session
      final session = await ref.read(gameActionsProvider).createSession(
        gameAreaId: savedArea.id,
        hidingPeriodSeconds: settings.hidingDuration.inSeconds,
        zoneRadiusMeters: settings.zoneRadius,
      );

      if (mounted) {
        context.go('/lobby/${session.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating game: $e')),
        );
      }
    }
  }
}

class GameSettings {
  final String areaName;
  final Duration hidingDuration;
  final double zoneRadius;

  GameSettings({
    required this.areaName,
    required this.hidingDuration,
    required this.zoneRadius,
  });
}
