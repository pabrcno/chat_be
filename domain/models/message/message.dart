import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/enums.dart';

part 'message.freezed.dart';
part 'message.g.dart';

@freezed
class Message with _$Message {
  const factory Message({
    required String id,
    required String content,
    required String chatId,
    required DateTime sentAt,
    required bool isUser,
    required EMessageRole role,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}
