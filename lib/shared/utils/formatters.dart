/// Utility functions for formatting values

class Formatters {
  /// Format a duration as MM:SS or H:MM:SS
  static String formatDuration(Duration duration) {
    if (duration.isNegative) return '0:00';

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format a duration as "Xh Ym" or "Xm"
  static String formatDurationWords(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Format distance in meters to appropriate unit
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  /// Format distance in meters to miles/feet
  static String formatDistanceImperial(double meters) {
    final feet = meters * 3.28084;
    if (feet < 528) {
      // Less than 0.1 miles
      return '${feet.round()} ft';
    }
    final miles = meters / 1609.344;
    if (miles < 0.1) {
      return '${feet.round()} ft';
    }
    return '${miles.toStringAsFixed(2)} mi';
  }

  /// Format a room code with spacing for readability
  static String formatRoomCode(String code) {
    if (code.length != 6) return code;
    return '${code.substring(0, 3)} ${code.substring(3)}';
  }

  /// Format a timestamp as relative time
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    }
    if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins min${mins == 1 ? '' : 's'} ago';
    }
    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours hour${hours == 1 ? '' : 's'} ago';
    }
    final days = difference.inDays;
    return '$days day${days == 1 ? '' : 's'} ago';
  }

  /// Format a coordinate as degrees/minutes/seconds
  static String formatCoordinate(double coord, bool isLatitude) {
    final direction = isLatitude
        ? (coord >= 0 ? 'N' : 'S')
        : (coord >= 0 ? 'E' : 'W');

    final absCoord = coord.abs();
    final degrees = absCoord.floor();
    final minutesDecimal = (absCoord - degrees) * 60;
    final minutes = minutesDecimal.floor();
    final seconds = ((minutesDecimal - minutes) * 60).round();

    return '$degrees°$minutes\'$seconds" $direction';
  }
}
