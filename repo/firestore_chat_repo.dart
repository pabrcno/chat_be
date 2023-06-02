import 'package:firebase_dart/firebase_dart.dart';
import 'package:firedart/firedart.dart';
import '../domain/core/constants.dart';
import '../domain/core/secrets.dart';
import '../domain/models/chat/chat.dart';
import '../domain/models/message/message.dart';
import '../domain/models/repo/i_chat_repo.dart';

class FirestoreStore implements IChatRepo {
  // Private constructor
  FirestoreStore._();

  // Asynchronous factory method
  static Future<FirestoreStore> create(Secrets secrets) async {
    final store = FirestoreStore._();
    await store._initializeFirebase(secrets);
    return store;
  }

  Future<void> _initializeFirebase(Secrets secrets) async {
    final options = FirebaseOptions(
      apiKey: secrets.firebaseAPIKey,
      projectId: PROJECT_ID,
      appId: secrets.firebaseAppId,
      messagingSenderId: secrets.firebaseMessagingSenderId,
    );

    if (Firebase.apps.isEmpty) {
      FirebaseDart.setup();

      await Firebase.initializeApp(name: 'chat', options: options);
      Firestore.initialize(options.projectId);
    }
  }

  @override
  Future<Chat> getChat(String chatId) async {
    final store = Firestore.instance;
    final chatReference = store.collection('chats').document(chatId);
    final chat =
        await chatReference.get().then((value) => Chat.fromJson(value.map));
    return chat;
  }

  @override
  Future<List<Message>> getMessages(String chatId) async {
    final store = Firestore.instance;
    final chatReference = store.collection('chats').document(chatId);
    final messages = await chatReference.collection('messages').get().then(
          (value) => value.map((e) => Message.fromJson(e.map)).toList(),
        );
    return messages;
  }
}
