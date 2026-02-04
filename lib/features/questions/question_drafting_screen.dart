import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/models/station.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/game_state_provider.dart';
import '../../core/services/station_service.dart';

/// Screen for drafting questions with map visualization
class QuestionDraftingScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const QuestionDraftingScreen({
    super.key,
    required this.sessionId,
  });

  @override
  ConsumerState<QuestionDraftingScreen> createState() => _QuestionDraftingScreenState();
}

class _QuestionDraftingScreenState extends ConsumerState<QuestionDraftingScreen> {
  GoogleMapController? _mapController;
  QuestionCategory _selectedCategory = QuestionCategory.radar;

  // Question-specific parameters
  double _radarRadius = 1000; // meters
  LatLng? _thermometerStart;
  LatLng? _thermometerEnd;
  double _tentaclesRadius = 2000; // meters
  String? _selectedLine;

  // Map state
  Set<Circle> _circles = {};
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(seekerGameStateProvider);
    final isEndgame = ref.watch(isEndgameProvider);
    final showSquish = ref.watch(showSquishBoundaryProvider);
    final squishRadius = ref.watch(squishRadiusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Draft Question'),
        actions: [
          // Endgame toggle
          IconButton(
            icon: Icon(
              isEndgame ? Icons.location_searching : Icons.my_location,
              color: isEndgame ? Colors.red : null,
            ),
            tooltip: isEndgame ? 'In Endgame' : 'Start Endgame',
            onPressed: () => _showEndgameDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category selector
          _buildCategorySelector(),

          // Map with overlays
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                _buildMap(gameState, showSquish, squishRadius),
                // Legend
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildLegend(showSquish),
                ),
                // Station list overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildStationList(),
                ),
              ],
            ),
          ),

          // Controls panel
          Expanded(
            flex: 2,
            child: _buildControlsPanel(gameState, showSquish, squishRadius),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: QuestionCategory.values.map((category) {
          final isSelected = category == _selectedCategory;
          final color = JetLagTheme.getCategoryColor(category.displayName);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: ChoiceChip(
              label: Text(category.displayName),
              selected: isSelected,
              selectedColor: color,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategory = category;
                    _updateMapOverlays();
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMap(SeekerGameState gameState, bool showSquish, double squishRadius) {
    final seekerPos = gameState.seekerPosition;
    final initialPosition = seekerPos != null
        ? LatLng(seekerPos.$1, seekerPos.$2)
        : const LatLng(40.7128, -74.0060); // Default to NYC

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialPosition,
        zoom: 14,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
        _updateMapOverlays();
      },
      onTap: _onMapTap,
      onLongPress: _onMapLongPress,
      circles: _circles,
      polylines: _polylines,
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      mapToolbarEnabled: false,
    );
  }

  Widget _buildLegend(bool showSquish) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _legendItem(Colors.green.withOpacity(0.3), 'Included'),
            if (showSquish)
              _legendItem(Colors.orange.withOpacity(0.3), 'Uncertain (squish)'),
            _legendItem(Colors.red.withOpacity(0.3), 'Excluded'),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: color.withOpacity(1)),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStationList() {
    final stationService = ref.watch(stationServiceProvider);
    final gameState = ref.watch(seekerGameStateProvider);
    final seekerPos = gameState.seekerPosition;

    if (seekerPos == null) {
      return const SizedBox.shrink();
    }

    // Get stations based on current question parameters
    final result = stationService.queryStationsForQuestion(
      centerLat: seekerPos.$1,
      centerLng: seekerPos.$2,
      questionRadiusMeters: _getQuestionRadius(),
      squishRadiusMeters: gameState.squishRadius,
      filterLines: _selectedLine != null ? [_selectedLine!] : null,
    );

    if (result.includedStations.isEmpty && result.uncertainStations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.train, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Stations',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Text(
                  '${result.includedStations.length} included',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
                  ),
                ),
                if (result.uncertainStations.isNotEmpty) ...[
                  const Text(' · '),
                  Text(
                    '${result.uncertainStations.length} uncertain',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                ...result.includedStations.map((s) => _stationChip(s, true)),
                ...result.uncertainStations.map((s) => _stationChip(s, false)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stationChip(Station station, bool included) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      child: Chip(
        avatar: Icon(
          Icons.train,
          size: 16,
          color: included ? Colors.green[700] : Colors.orange[700],
        ),
        label: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              station.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            if (station.lines.isNotEmpty)
              Text(
                station.lines.join(', '),
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
          ],
        ),
        backgroundColor: included
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        side: BorderSide(
          color: included ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
    );
  }

  Widget _buildControlsPanel(SeekerGameState gameState, bool showSquish, double squishRadius) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category-specific controls
          Expanded(
            child: _buildCategoryControls(),
          ),

          // Squish radius control (when not in endgame)
          if (showSquish) ...[
            const Divider(),
            _buildSquishControl(squishRadius),
          ],

          // Ask question button
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _askQuestion,
              icon: const Icon(Icons.send),
              label: const Text('Ask Question'),
              style: ElevatedButton.styleFrom(
                backgroundColor: JetLagTheme.getCategoryColor(_selectedCategory.displayName),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryControls() {
    switch (_selectedCategory) {
      case QuestionCategory.radar:
        return _buildRadarControls();
      case QuestionCategory.thermometer:
        return _buildThermometerControls();
      case QuestionCategory.tentacles:
        return _buildTentaclesControls();
      case QuestionCategory.matching:
        return _buildMatchingControls();
      case QuestionCategory.measuring:
        return _buildMeasuringControls();
      case QuestionCategory.photo:
        return _buildPhotoControls();
    }
  }

  Widget _buildRadarControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Radar: Are you within X of our location?',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Text('Distance: ${_formatDistance(_radarRadius)}'),
        Slider(
          value: _radarRadius,
          min: 100,
          max: 10000,
          divisions: 99,
          label: _formatDistance(_radarRadius),
          onChanged: (value) {
            setState(() {
              _radarRadius = value;
              _updateMapOverlays();
            });
          },
        ),
        Wrap(
          spacing: 8,
          children: [
            _quickRadiusButton(250, '250m'),
            _quickRadiusButton(500, '500m'),
            _quickRadiusButton(1000, '1km'),
            _quickRadiusButton(2000, '2km'),
            _quickRadiusButton(5000, '5km'),
          ],
        ),
      ],
    );
  }

  Widget _quickRadiusButton(double meters, String label) {
    final isSelected = (_radarRadius - meters).abs() < 10;
    return ActionChip(
      label: Text(label),
      backgroundColor: isSelected ? JetLagTheme.radarColor.withOpacity(0.2) : null,
      onPressed: () {
        setState(() {
          _radarRadius = meters;
          _updateMapOverlays();
        });
      },
    );
  }

  Widget _buildThermometerControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thermometer: We moved X, warmer or colder?',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        const Text('Tap map to set start point, long press for end point'),
        const SizedBox(height: 8),
        if (_thermometerStart != null && _thermometerEnd != null) ...[
          Text(
            'Distance moved: ${_formatDistance(_calculateDistance(_thermometerStart!, _thermometerEnd!))}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _thermometerStart = null;
                    _thermometerEnd = null;
                    _updateMapOverlays();
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _useCurrentLocationAsStart,
                icon: const Icon(Icons.my_location),
                label: const Text('Use Current'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTentaclesControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tentacles: Of all X within radius, which is closest to you?',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Text('Radius: ${_formatDistance(_tentaclesRadius)}'),
        Slider(
          value: _tentaclesRadius,
          min: 500,
          max: 10000,
          divisions: 95,
          label: _formatDistance(_tentaclesRadius),
          onChanged: (value) {
            setState(() {
              _tentaclesRadius = value;
              _updateMapOverlays();
            });
          },
        ),
        const Text('Select what to look for:'),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('Stations'),
              selected: true,
              onSelected: (v) {},
            ),
            FilterChip(
              label: const Text('Libraries'),
              selected: false,
              onSelected: (v) {},
            ),
            FilterChip(
              label: const Text('Parks'),
              selected: false,
              onSelected: (v) {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMatchingControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Matching: Is your closest X the same as ours?',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        const Text('Your closest station will be shown on the map'),
        const SizedBox(height: 16),
        const Text('Compare:'),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Station'),
              selected: true,
              onSelected: (v) {},
            ),
            ChoiceChip(
              label: const Text('Park'),
              selected: false,
              onSelected: (v) {},
            ),
            ChoiceChip(
              label: const Text('Library'),
              selected: false,
              onSelected: (v) {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMeasuringControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Measuring: Are you closer to X than we are?',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        const Text('Tap the map to select the target location'),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Or search for a location',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            // TODO: Implement location search
          },
        ),
      ],
    );
  }

  Widget _buildPhotoControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photo: Send us a picture of X',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        const Text('Select what to request:'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(label: const Text('Station sign'), selected: true, onSelected: (v) {}),
            ChoiceChip(label: const Text('Street sign'), selected: false, onSelected: (v) {}),
            ChoiceChip(label: const Text('Current view'), selected: false, onSelected: (v) {}),
            ChoiceChip(label: const Text('Largest building'), selected: false, onSelected: (v) {}),
            ChoiceChip(label: const Text('Custom...'), selected: false, onSelected: (v) {}),
          ],
        ),
      ],
    );
  }

  Widget _buildSquishControl(double currentRadius) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.blur_on, size: 16, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text(
              'Uncertainty Zone (hider movement)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const Spacer(),
            Text(
              _formatDistance(currentRadius),
              style: TextStyle(
                color: Colors.orange[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: currentRadius,
          min: 0,
          max: 1609, // 1 mile
          divisions: 32,
          activeColor: Colors.orange,
          label: _formatDistance(currentRadius),
          onChanged: (value) {
            ref.read(seekerGameStateProvider.notifier).setSquishRadius(value);
            _updateMapOverlays();
          },
        ),
      ],
    );
  }

  void _showEndgameDialog(BuildContext context) {
    final isEndgame = ref.read(isEndgameProvider);

    if (isEndgame) {
      // Show endgame status
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Endgame Active'),
          content: const Text(
            'You are in the hiding zone. The hider cannot move.\n\n'
            'Questions are now exact - no uncertainty zone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      // Confirm starting endgame
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start Endgame?'),
          content: const Text(
            'Starting the endgame means you are in the hiding zone.\n\n'
            'The hider will be notified and cannot move.\n'
            'Questions will be exact (no uncertainty zone).\n\n'
            'Are you sure?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(seekerGameStateProvider.notifier).startEndgame();
                Navigator.pop(context);
                _updateMapOverlays();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Start Endgame'),
            ),
          ],
        ),
      );
    }
  }

  void _onMapTap(LatLng position) {
    if (_selectedCategory == QuestionCategory.thermometer) {
      setState(() {
        _thermometerStart = position;
        _updateMapOverlays();
      });
    } else if (_selectedCategory == QuestionCategory.measuring) {
      // Set target location for measuring
      _updateMapOverlays();
    }
  }

  void _onMapLongPress(LatLng position) {
    if (_selectedCategory == QuestionCategory.thermometer) {
      setState(() {
        _thermometerEnd = position;
        _updateMapOverlays();
      });
    }
  }

  void _useCurrentLocationAsStart() {
    final gameState = ref.read(seekerGameStateProvider);
    final pos = gameState.seekerPosition;
    if (pos != null) {
      setState(() {
        _thermometerStart = LatLng(pos.$1, pos.$2);
        _updateMapOverlays();
      });
    }
  }

  void _updateMapOverlays() {
    final gameState = ref.read(seekerGameStateProvider);
    final showSquish = ref.read(showSquishBoundaryProvider);
    final squishRadius = ref.read(squishRadiusProvider);
    final seekerPos = gameState.seekerPosition;

    if (seekerPos == null) return;

    final center = LatLng(seekerPos.$1, seekerPos.$2);
    final newCircles = <Circle>{};
    final newPolylines = <Polyline>{};
    final newMarkers = <Marker>{};

    switch (_selectedCategory) {
      case QuestionCategory.radar:
        // Inner circle (question radius)
        newCircles.add(Circle(
          circleId: const CircleId('radar_inner'),
          center: center,
          radius: _radarRadius,
          fillColor: Colors.green.withOpacity(0.2),
          strokeColor: Colors.green,
          strokeWidth: 2,
        ));
        // Outer circle (with squish)
        if (showSquish) {
          newCircles.add(Circle(
            circleId: const CircleId('radar_outer'),
            center: center,
            radius: _radarRadius + squishRadius,
            fillColor: Colors.orange.withOpacity(0.1),
            strokeColor: Colors.orange,
            strokeWidth: 2,
          ));
        }
        break;

      case QuestionCategory.thermometer:
        if (_thermometerStart != null) {
          newMarkers.add(Marker(
            markerId: const MarkerId('therm_start'),
            position: _thermometerStart!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: const InfoWindow(title: 'Start'),
          ));
        }
        if (_thermometerEnd != null) {
          newMarkers.add(Marker(
            markerId: const MarkerId('therm_end'),
            position: _thermometerEnd!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: const InfoWindow(title: 'End'),
          ));
        }
        if (_thermometerStart != null && _thermometerEnd != null) {
          newPolylines.add(Polyline(
            polylineId: const PolylineId('therm_line'),
            points: [_thermometerStart!, _thermometerEnd!],
            color: Colors.orange,
            width: 4,
          ));
          // Draw perpendicular bisector line
          final midpoint = LatLng(
            (_thermometerStart!.latitude + _thermometerEnd!.latitude) / 2,
            (_thermometerStart!.longitude + _thermometerEnd!.longitude) / 2,
          );
          final bisectorPoints = _calculatePerpendicularBisector(
            _thermometerStart!,
            _thermometerEnd!,
            0.01, // length in degrees
          );
          newPolylines.add(Polyline(
            polylineId: const PolylineId('therm_bisector'),
            points: bisectorPoints,
            color: Colors.red,
            width: 2,
            patterns: [PatternItem.dash(10), PatternItem.gap(10)],
          ));
        }
        break;

      case QuestionCategory.tentacles:
        // Circle showing the radius
        newCircles.add(Circle(
          circleId: const CircleId('tentacles_radius'),
          center: center,
          radius: _tentaclesRadius,
          fillColor: Colors.teal.withOpacity(0.15),
          strokeColor: Colors.teal,
          strokeWidth: 2,
        ));
        if (showSquish) {
          newCircles.add(Circle(
            circleId: const CircleId('tentacles_outer'),
            center: center,
            radius: _tentaclesRadius + squishRadius,
            fillColor: Colors.orange.withOpacity(0.1),
            strokeColor: Colors.orange,
            strokeWidth: 1,
          ));
        }
        break;

      case QuestionCategory.matching:
      case QuestionCategory.measuring:
        // Show seeker's closest station
        newMarkers.add(Marker(
          markerId: const MarkerId('seeker_pos'),
          position: center,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Your position'),
        ));
        break;

      case QuestionCategory.photo:
        // No special overlays for photo
        break;
    }

    setState(() {
      _circles = newCircles;
      _polylines = newPolylines;
      _markers = newMarkers;
    });
  }

  List<LatLng> _calculatePerpendicularBisector(LatLng p1, LatLng p2, double length) {
    final midLat = (p1.latitude + p2.latitude) / 2;
    final midLng = (p1.longitude + p2.longitude) / 2;

    final dx = p2.longitude - p1.longitude;
    final dy = p2.latitude - p1.latitude;

    // Perpendicular direction
    final perpDx = -dy;
    final perpDy = dx;

    // Normalize and scale
    final mag = math.sqrt(perpDx * perpDx + perpDy * perpDy);
    if (mag == 0) return [LatLng(midLat, midLng)];

    final normDx = perpDx / mag * length;
    final normDy = perpDy / mag * length;

    return [
      LatLng(midLat - normDy, midLng - normDx),
      LatLng(midLat + normDy, midLng + normDx),
    ];
  }

  double _getQuestionRadius() {
    switch (_selectedCategory) {
      case QuestionCategory.radar:
        return _radarRadius;
      case QuestionCategory.tentacles:
        return _tentaclesRadius;
      default:
        return 2000; // Default radius for station search
    }
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    const earthRadius = 6371000.0;
    final dLat = (p2.latitude - p1.latitude) * math.pi / 180;
    final dLng = (p2.longitude - p1.longitude) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(p1.latitude * math.pi / 180) *
            math.cos(p2.latitude * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  void _askQuestion() {
    // TODO: Implement question submission
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Asking ${_selectedCategory.displayName} question...'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {},
        ),
      ),
    );
  }
}
