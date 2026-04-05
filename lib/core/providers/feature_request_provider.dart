import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/feature_request.dart';
import '../services/supabase_init.dart';

final featureRequestsProvider = FutureProvider<List<FeatureRequest>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  if (service == null) return [];
  return service.getFeatureRequests();
});

class FeatureRequestActions {
  final Ref ref;
  FeatureRequestActions(this.ref);

  Future<FeatureRequest?> submit({
    required String title,
    String? description,
    String? submitterName,
  }) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return null;
    final result = await service.submitFeatureRequest(
      title: title,
      description: description,
      submitterName: submitterName,
    );
    ref.invalidate(featureRequestsProvider);
    return result;
  }
}

final featureRequestActionsProvider = Provider((ref) => FeatureRequestActions(ref));
