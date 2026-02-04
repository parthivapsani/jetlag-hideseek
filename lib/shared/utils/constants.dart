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
  static const int relativeResponseTime = 5;
  static const int radarResponseTime = 5;
  static const int photoResponseTime = 15;
  static const int oddballResponseTime = 5;
  static const int precisionResponseTime = 5;

  // Card draw amounts
  static const int relativeCardsDrawn = 2;
  static const int radarCardsDrawn = 2;
  static const int photoCardsDrawn = 1;
  static const int oddballCardsDrawn = 1;
  static const int precisionCardsDrawn = 1;

  // Coin costs
  static const int relativeCoinCost = 40;
  static const int radarCoinCost = 30;
  static const int photoCoinCost = 15;
  static const int oddballCoinCost = 10;
  static const int precisionCoinCost = 10;

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
