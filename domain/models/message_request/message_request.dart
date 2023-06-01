import 'package:freezed_annotation/freezed_annotation.dart';
part 'message_request.freezed.dart';
part 'message_request.g.dart';

@freezed
class MessageRequest with _$MessageRequest {
  const factory MessageRequest({
    required String userToken,
    required String chatId,
  }) = _MessageRequest;

  factory MessageRequest.fromJson(Map<String, dynamic> json) =>
      _$MessageRequestFromJson(json);
}
