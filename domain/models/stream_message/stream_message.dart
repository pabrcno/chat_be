import '../message/message.dart';

class StreamMessage {
  StreamMessage({
    required this.message,
    this.finishReason,
  });
  Message message;
  String? finishReason;
}
