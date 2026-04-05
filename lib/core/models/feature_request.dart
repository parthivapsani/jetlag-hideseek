import 'package:freezed_annotation/freezed_annotation.dart';

part 'feature_request.freezed.dart';
part 'feature_request.g.dart';

enum FeatureRequestStatus {
  @JsonValue('open')
  open,
  @JsonValue('in_progress')
  inProgress,
  @JsonValue('done')
  done,
}

@freezed
class FeatureRequest with _$FeatureRequest {
  const factory FeatureRequest({
    required String id,
    required String title,
    String? description,
    @Default(FeatureRequestStatus.open) FeatureRequestStatus status,
    String? submitterName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _FeatureRequest;

  factory FeatureRequest.fromJson(Map<String, dynamic> json) => _$FeatureRequestFromJson(json);
}
