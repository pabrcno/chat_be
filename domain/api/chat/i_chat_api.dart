import '../../models/message/message.dart';
import '../../models/stream_message/stream_message.dart';

abstract class IChatApi {
  Future<Message> createChatCompletion(
      List<Message> messages, String chatId, String model);
  Stream<StreamMessage> createChatCompletionStream(
    List<Message> messages,
    double? temperature,
    String model,
  );
}
