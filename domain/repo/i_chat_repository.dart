import '../models/chat/chat.dart';

abstract class IChatRepository {
  Future<Chat?> getChat(String chatId);
}
