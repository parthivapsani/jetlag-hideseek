import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_init.dart';

/// Estimated costs per API call in cents (1/100 of a dollar).
/// Based on Google Maps Platform pricing (as of 2024).
class _ApiCosts {
  static const int mapLoad = 700; // $7 per 1000 loads = 0.7 cents each
  static const int placesAutocomplete = 283; // $2.83 per 1000
  static const int placesDetails = 1700; // $17 per 1000
  static const int geocoding = 500; // $5 per 1000
}

class ApiUsageService {
  final SupabaseClient _client;

  ApiUsageService(this._client);

  Future<void> trackMapLoad({String? sessionId}) async {
    await _insert('map_load', _ApiCosts.mapLoad, sessionId);
  }

  Future<void> trackPlacesAutocomplete({String? sessionId}) async {
    await _insert('places_autocomplete', _ApiCosts.placesAutocomplete, sessionId);
  }

  Future<void> trackPlacesDetails({String? sessionId}) async {
    await _insert('places_details', _ApiCosts.placesDetails, sessionId);
  }

  Future<void> trackGeocoding({String? sessionId}) async {
    await _insert('geocoding', _ApiCosts.geocoding, sessionId);
  }

  Future<void> _insert(String type, int costCents, String? sessionId) async {
    try {
      await _client.from('api_usage').insert({
        'api_type': type,
        'session_id': sessionId,
        'estimated_cost_cents': costCents,
      });
    } catch (_) {
      // Don't let tracking failures break the app
    }
  }

  /// Get usage stats for the current month.
  Future<ApiUsageStats> getCurrentMonthStats() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final response = await _client
        .from('api_usage')
        .select()
        .gte('created_at', monthStart.toIso8601String())
        .order('created_at');

    final rows = response as List;

    // Aggregate
    final byType = <String, _TypeStats>{};
    int totalCostCents = 0;

    for (final row in rows) {
      final type = row['api_type'] as String;
      final cost = (row['estimated_cost_cents'] as int?) ?? 0;
      totalCostCents += cost;

      byType.putIfAbsent(type, () => _TypeStats(type));
      byType[type]!.count++;
      byType[type]!.totalCostCents += cost;
    }

    // Calculate projection
    final dayOfMonth = now.day;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final projectedCostCents = dayOfMonth > 0
        ? (totalCostCents / dayOfMonth * daysInMonth).round()
        : 0;

    return ApiUsageStats(
      totalCostCents: totalCostCents,
      projectedCostCents: projectedCostCents,
      freeTierCents: 20000, // $200
      byType: byType.values
          .map((t) => ApiTypeBreakdown(
                apiType: t.type,
                count: t.count,
                costCents: t.totalCostCents,
              ))
          .toList()
        ..sort((a, b) => b.costCents.compareTo(a.costCents)),
      totalCalls: rows.length,
    );
  }
}

class _TypeStats {
  final String type;
  int count = 0;
  int totalCostCents = 0;
  _TypeStats(this.type);
}

class ApiUsageStats {
  final int totalCostCents;
  final int projectedCostCents;
  final int freeTierCents;
  final List<ApiTypeBreakdown> byType;
  final int totalCalls;

  ApiUsageStats({
    required this.totalCostCents,
    required this.projectedCostCents,
    required this.freeTierCents,
    required this.byType,
    required this.totalCalls,
  });

  double get usagePercent =>
      freeTierCents > 0 ? (totalCostCents / freeTierCents).clamp(0.0, 1.0) : 0.0;

  String get totalCostFormatted =>
      '\$${(totalCostCents / 100).toStringAsFixed(2)}';

  String get projectedCostFormatted =>
      '\$${(projectedCostCents / 100).toStringAsFixed(2)}';

  String get freeTierFormatted =>
      '\$${(freeTierCents / 100).toStringAsFixed(0)}';
}

class ApiTypeBreakdown {
  final String apiType;
  final int count;
  final int costCents;

  ApiTypeBreakdown({
    required this.apiType,
    required this.count,
    required this.costCents,
  });

  String get costFormatted => '\$${(costCents / 100).toStringAsFixed(2)}';

  String get displayName {
    switch (apiType) {
      case 'map_load':
        return 'Map Loads';
      case 'places_autocomplete':
        return 'Places Autocomplete';
      case 'places_details':
        return 'Places Details';
      case 'geocoding':
        return 'Geocoding';
      default:
        return apiType;
    }
  }
}

// ============ Provider ============

final apiUsageServiceProvider = Provider<ApiUsageService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return ApiUsageService(client);
});

final apiUsageStatsProvider = FutureProvider<ApiUsageStats?>((ref) async {
  final service = ref.watch(apiUsageServiceProvider);
  if (service == null) return null;
  return service.getCurrentMonthStats();
});
