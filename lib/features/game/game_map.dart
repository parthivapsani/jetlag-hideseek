import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/location_service.dart';
import '../../app/theme.dart';

class GameMap extends ConsumerStatefulWidget {
  final bool showHiderZone;
  final bool showSeekerLocations;
  final LatLng? hiderLocation;
  final double? zoneRadius;

  const GameMap({
    super.key,
    this.showHiderZone = false,
    this.showSeekerLocations = true,
    this.hiderLocation,
    this.zoneRadius,
  });

  @override
  ConsumerState<GameMap> createState() => _GameMapState();
}

class _GameMapState extends ConsumerState<GameMap> {
  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(currentSessionProvider);
    final gameAreaAsync = sessionAsync.whenData((session) {
      if (session == null) return null;
      return ref.watch(gameAreaProvider(session.gameAreaId));
    });

    return gameAreaAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (areaAsync) {
        return areaAsync?.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
              data: (gameArea) => _buildMap(gameArea),
            ) ??
            const Center(child: Text('No game area'));
      },
    );
  }

  Widget _buildMap(GameArea? gameArea) {
    if (gameArea == null) {
      return const Center(child: Text('Game area not found'));
    }

    final session = ref.watch(currentSessionProvider).valueOrNull;
    final participants = ref.watch(participantsProvider).valueOrNull ?? [];
    final currentParticipant = ref.watch(currentParticipantProvider);
    final locationService = ref.watch(locationServiceProvider);

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(gameArea.centerLat, gameArea.centerLng),
        zoom: gameArea.defaultZoom,
      ),
      onMapCreated: (controller) => _mapController = controller,
      polygons: _buildPolygons(gameArea),
      circles: _buildCircles(session, locationService),
      markers: _buildMarkers(participants, currentParticipant),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  Set<Polygon> _buildPolygons(GameArea area) {
    final polygons = <Polygon>{};

    // Game area boundaries
    for (final polygon in area.inclusionPolygons) {
      if (polygon.points.length >= 3) {
        polygons.add(Polygon(
          polygonId: PolygonId('inclusion_${polygon.id}'),
          points: polygon.toLatLngList(),
          fillColor: JetLagTheme.primaryBlue.withOpacity(0.1),
          strokeColor: JetLagTheme.primaryBlue,
          strokeWidth: 3,
        ));
      }
    }

    // Exclusion zones
    for (final polygon in area.exclusionPolygons) {
      if (polygon.points.length >= 3) {
        polygons.add(Polygon(
          polygonId: PolygonId('exclusion_${polygon.id}'),
          points: polygon.toLatLngList(),
          fillColor: Colors.red.withOpacity(0.2),
          strokeColor: Colors.red,
          strokeWidth: 2,
        ));
      }
    }

    return polygons;
  }

  Set<Circle> _buildCircles(GameSession? session, LocationService locationService) {
    final circles = <Circle>{};

    // Hider zone
    if (widget.showHiderZone && widget.hiderLocation != null) {
      final radius = widget.zoneRadius ?? session?.zoneRadiusMeters ?? 804.672;
      circles.add(Circle(
        circleId: const CircleId('hider_zone'),
        center: widget.hiderLocation!,
        radius: radius,
        fillColor: JetLagTheme.hiderGreen.withOpacity(0.2),
        strokeColor: JetLagTheme.hiderGreen,
        strokeWidth: 3,
      ));
    }

    return circles;
  }

  Set<Marker> _buildMarkers(List<Participant> participants, Participant? currentParticipant) {
    final markers = <Marker>{};

    if (!widget.showSeekerLocations) return markers;

    // Show seeker locations for hider
    final seekers = participants.where((p) => p.role == ParticipantRole.seeker).toList();
    for (final seeker in seekers) {
      if (seeker.lastLocationLat != null && seeker.lastLocationLng != null) {
        markers.add(Marker(
          markerId: MarkerId('seeker_${seeker.id}'),
          position: LatLng(seeker.lastLocationLat!, seeker.lastLocationLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: seeker.displayName),
        ));
      }
    }

    return markers;
  }

  void animateToLocation(LatLng location, {double? zoom}) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: location,
          zoom: zoom ?? 15,
        ),
      ),
    );
  }
}
