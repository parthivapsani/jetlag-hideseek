/// App-wide constants

class AppConstants {
  // Game settings
  static const int defaultHidingPeriodSeconds = 3600; // 1 hour
  static const double defaultZoneRadiusMeters = 804.672; // 0.5 miles
  static const int categoryCooldownMinutes = 30;

  // Room codes
  static const int roomCodeLength = 6;
  static const String roomCodeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  // Map settings
  static const double defaultMapZoom = 12.0;
  static const double maxMapZoom = 20.0;
  static const double minMapZoom = 5.0;

  // Timer settings
  static const int timerUpdateIntervalSeconds = 1;

  // Location settings
  static const int locationUpdateDistanceMeters = 10;

  // Question response times (in minutes)
  static const int matchingResponseTime = 5;
  static const int measuringResponseTime = 5;
  static const int radarResponseTime = 5;
  static const int thermometerResponseTime = 5;
  static const int tentaclesResponseTime = 5;
  static const int photoResponseTime = 15;

  // Card draw amounts
  static const int matchingCardsDrawn = 2;
  static const int measuringCardsDrawn = 2;
  static const int radarCardsDrawn = 2;
  static const int thermometerCardsDrawn = 1;
  static const int tentaclesCardsDrawn = 1;
  static const int photoCardsDrawn = 1;

  // Coin costs
  static const int matchingCoinCost = 30;
  static const int measuringCoinCost = 30;
  static const int radarCoinCost = 25;
  static const int thermometerCoinCost = 20;
  static const int tentaclesCoinCost = 20;
  static const int photoCoinCost = 15;

  // Distance conversions
  static const double metersPerMile = 1609.344;
  static const double metersPerFoot = 0.3048;
  static const double feetPerMile = 5280;
}

class StorageKeys {
  static const String deviceToken = 'device_token';
  static const String displayName = 'display_name';
  static const String lastSessionId = 'last_session_id';
  static const String savedGameAreas = 'saved_game_areas';
}
