import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Estimates how far a person could travel in a given time
/// Creates isochrone-like boundaries for the map
class TravelEstimator {
  // Speed constants (meters per second)
  static const double walkingSpeedMps = 1.4; // ~5 km/h, ~3.1 mph
  static const double briskWalkingSpeedMps = 1.8; // ~6.5 km/h, ~4 mph
  static const double joggingSpeedMps = 2.8; // ~10 km/h, ~6.2 mph
  static const double runningSpeedMps = 4.0; // ~14.4 km/h, ~9 mph
  static const double sprintingSpeedMps = 6.0; // ~21.6 km/h, ~13.4 mph

  // Transit speeds (average including wait times and transfers)
  static const double subwaySpeedMps = 8.3; // ~30 km/h, ~18.6 mph effective
  static const double busSpeedMps = 5.5; // ~20 km/h, ~12.4 mph effective
  static const double trainSpeedMps = 13.9; // ~50 km/h, ~31 mph effective

  /// Estimate travel radius for different modes
  static TravelEstimate estimateTravelRadius({
    required Duration duration,
    bool includeTransit = true,
    double walkingRatio = 0.7, // 70% walking, 30% light jogging
    double transitEfficiency = 0.6, // Transit isn't always available
  }) {
    final seconds = duration.inSeconds.toDouble();

    // Pure walking radius
    final pureWalkingRadius = seconds * walkingSpeedMps;

    // Mixed walking/jogging radius
    final mixedRadius = seconds * (walkingSpeedMps * walkingRatio +
                                    joggingSpeedMps * (1 - walkingRatio));

    // Maximum with some running
    final maxFootRadius = seconds * (walkingSpeedMps * 0.5 +
                                      joggingSpeedMps * 0.3 +
                                      runningSpeedMps * 0.2);

    // With transit (if available)
    double transitRadius = 0;
    if (includeTransit && seconds > 300) { // Only consider transit for >5 min
      // Assume: walk to station (3 min), wait (5 min avg), ride, walk from station (3 min)
      final effectiveTransitTime = math.max(0, seconds - 660); // 11 min overhead
      transitRadius = effectiveTransitTime * subwaySpeedMps * transitEfficiency +
                      660 * walkingSpeedMps; // Walking portion
    }

    return TravelEstimate(
      conservativeRadius: pureWalkingRadius,
      likelyRadius: mixedRadius,
      maximumRadius: math.max(maxFootRadius, transitRadius),
      withTransitRadius: transitRadius > 0 ? transitRadius : null,
      duration: duration,
    );
  }

  /// Generate polygon points for a travel boundary
  /// Uses irregular shapes to look more realistic than a perfect circle
  static List<LatLng> generateTravelBoundary(
    LatLng center,
    double radiusMeters, {
    int points = 72,
    double irregularity = 0.15, // 15% variation for natural look
    int? seed,
  }) {
    final random = math.Random(seed ?? DateTime.now().millisecondsSinceEpoch);
    final result = <LatLng>[];

    // Convert radius to degrees (approximate)
    final radiusLat = radiusMeters / 111320; // meters per degree latitude
    final radiusLng = radiusMeters / (111320 * math.cos(center.latitude * math.pi / 180));

    for (int i = 0; i < points; i++) {
      final angle = (i * 2 * math.pi) / points;

      // Add some randomness for natural look
      final variation = 1.0 + (random.nextDouble() - 0.5) * 2 * irregularity;

      // Make it slightly elongated along roads (N-S and E-W tend to be faster)
      final directionalBonus = 1.0 + 0.1 * math.cos(angle * 2).abs();

      final effectiveRadius = variation * directionalBonus;

      final lat = center.latitude + radiusLat * math.cos(angle) * effectiveRadius;
      final lng = center.longitude + radiusLng * math.sin(angle) * effectiveRadius;

      result.add(LatLng(lat, lng));
    }

    // Close the polygon
    if (result.isNotEmpty) {
      result.add(result.first);
    }

    return result;
  }

  /// Generate multiple concentric boundaries for visualization
  static List<TravelBoundary> generateTravelBoundaries(
    LatLng center,
    Duration duration, {
    bool includeTransit = true,
  }) {
    final estimate = estimateTravelRadius(
      duration: duration,
      includeTransit: includeTransit,
    );

    final boundaries = <TravelBoundary>[];
    final seed = center.latitude.hashCode ^ center.longitude.hashCode;

    // Conservative (pure walking)
    boundaries.add(TravelBoundary(
      type: TravelBoundaryType.conservative,
      label: 'Walking only',
      radiusMeters: estimate.conservativeRadius,
      points: generateTravelBoundary(
        center,
        estimate.conservativeRadius,
        irregularity: 0.1,
        seed: seed,
      ),
    ));

    // Likely (mixed walking/jogging)
    boundaries.add(TravelBoundary(
      type: TravelBoundaryType.likely,
      label: 'Walking + light jogging',
      radiusMeters: estimate.likelyRadius,
      points: generateTravelBoundary(
        center,
        estimate.likelyRadius,
        irregularity: 0.15,
        seed: seed + 1,
      ),
    ));

    // Maximum (with running)
    boundaries.add(TravelBoundary(
      type: TravelBoundaryType.maximum,
      label: 'With running',
      radiusMeters: estimate.maximumRadius,
      points: generateTravelBoundary(
        center,
        estimate.maximumRadius,
        irregularity: 0.2,
        seed: seed + 2,
      ),
    ));

    // With transit (if applicable)
    if (estimate.withTransitRadius != null) {
      boundaries.add(TravelBoundary(
        type: TravelBoundaryType.withTransit,
        label: 'With transit',
        radiusMeters: estimate.withTransitRadius!,
        points: generateTravelBoundary(
          center,
          estimate.withTransitRadius!,
          irregularity: 0.25, // More irregular due to transit routes
          seed: seed + 3,
        ),
      ));
    }

    return boundaries;
  }

  /// Calculate time-based boundaries at intervals
  static List<TimedBoundary> generateTimedBoundaries(
    LatLng center, {
    required Duration maxDuration,
    Duration interval = const Duration(minutes: 15),
    TravelBoundaryType type = TravelBoundaryType.likely,
  }) {
    final boundaries = <TimedBoundary>[];
    var currentDuration = interval;

    while (currentDuration <= maxDuration) {
      final estimate = estimateTravelRadius(duration: currentDuration);
      final radius = switch (type) {
        TravelBoundaryType.conservative => estimate.conservativeRadius,
        TravelBoundaryType.likely => estimate.likelyRadius,
        TravelBoundaryType.maximum => estimate.maximumRadius,
        TravelBoundaryType.withTransit => estimate.withTransitRadius ?? estimate.maximumRadius,
      };

      boundaries.add(TimedBoundary(
        duration: currentDuration,
        radiusMeters: radius,
        points: generateTravelBoundary(
          center,
          radius,
          irregularity: 0.12,
          seed: currentDuration.inMinutes,
        ),
      ));

      currentDuration += interval;
    }

    return boundaries;
  }
}

class TravelEstimate {
  final double conservativeRadius; // Pure walking
  final double likelyRadius; // Walking + light jogging
  final double maximumRadius; // With running
  final double? withTransitRadius; // If transit available
  final Duration duration;

  const TravelEstimate({
    required this.conservativeRadius,
    required this.likelyRadius,
    required this.maximumRadius,
    this.withTransitRadius,
    required this.duration,
  });

  String get conservativeFormatted => _formatDistance(conservativeRadius);
  String get likelyFormatted => _formatDistance(likelyRadius);
  String get maximumFormatted => _formatDistance(maximumRadius);
  String? get withTransitFormatted =>
      withTransitRadius != null ? _formatDistance(withTransitRadius!) : null;

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    final miles = meters / 1609.344;
    return '${miles.toStringAsFixed(1)} mi';
  }
}

enum TravelBoundaryType {
  conservative,
  likely,
  maximum,
  withTransit,
}

class TravelBoundary {
  final TravelBoundaryType type;
  final String label;
  final double radiusMeters;
  final List<LatLng> points;

  const TravelBoundary({
    required this.type,
    required this.label,
    required this.radiusMeters,
    required this.points,
  });
}

class TimedBoundary {
  final Duration duration;
  final double radiusMeters;
  final List<LatLng> points;

  const TimedBoundary({
    required this.duration,
    required this.radiusMeters,
    required this.points,
  });

  String get durationFormatted {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
