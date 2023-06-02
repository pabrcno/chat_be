import '../chat/chat.dart';
import '../message/message.dart';

abstract class IChatRepo {
  Future<Chat> getChat(String chatId);
  Future<List<Message>> getMessages(String chatId);
}
