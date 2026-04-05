import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_usage.freezed.dart';
part 'api_usage.g.dart';

@freezed
class ApiUsage with _$ApiUsage {
  const factory ApiUsage({
    required String id,
    required String apiType,
    String? sessionId,
    @Default(0) int estimatedCostCents,
    DateTime? createdAt,
  }) = _ApiUsage;

  factory ApiUsage.fromJson(Map<String, dynamic> json) =>
      _$ApiUsageFromJson(json);
}
