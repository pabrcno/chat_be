import '../chat/chat.dart';
import '../message/message.dart';

class ChatData {
  ChatData(this.chat, this.messages);
  final Chat chat;
  final List<Message> messages;
}
