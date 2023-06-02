// routes/ws.dart
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_web_socket/dart_frog_web_socket.dart';
import 'package:dotenv/dotenv.dart';
import 'package:firebase_dart/firebase_dart.dart';
import 'package:firedart/firedart.dart';
import 'package:http/http.dart' as http;

import '../api/openAi/chat_api.dart';
import '../domain/api/chat/i_chat_api.dart';
import '../domain/models/chat/chat.dart';
import '../domain/models/message/message.dart';
import '../domain/models/message_request/message_request.dart';

Future<Response> onRequest(RequestContext context) async {
  checkForEnvs();
  final env = DotEnv(includePlatformEnvironment: true)..load();

  final options = FirebaseOptions(
    apiKey: env['FIREBASE_API_KEY'] ??
        Platform.environment['FIREBASE_API_KEY'] ??
        '',
    projectId: env['FIREBASE_PROJECT_ID'] ??
        Platform.environment['FIREBASE_API_KEY'] ??
        '',
    appId: env['FIREBASE_APP_ID'] ??
        Platform.environment['FIREBASE_API_KEY'] ??
        '',
    messagingSenderId: env['FIREBASE_MESSAGING_SENDER_ID'] ??
        Platform.environment['FIREBASE_MESSAGING_SENDER_ID'] ??
        '',
  );

  if (Firebase.apps.isEmpty) {
    FirebaseDart.setup();

    await Firebase.initializeApp(name: 'chat', options: options);
    Firestore.initialize(options.projectId);
  }

  final handler = webSocketHandler(
    (channel, protocol) {
      channel.stream.listen(
        (event) async {
          final json = jsonDecode(event as String) as Map<String, dynamic>;
          final messageRequest = MessageRequest.fromJson(
            json,
          );
          await verifyIdToken(messageRequest.userToken);
          final IChatApi openAIChatApi = OpenAIChatApi();

          final store = Firestore.instance;

          final chatReference =
              store.collection('chats').document(messageRequest.chatId);
          final chat = await chatReference
              .get()
              .then((value) => Chat.fromJson(value.map));
          final messages =
              await chatReference.collection('messages').get().then(
                    (value) => value
                        .map(
                          (e) => Message.fromJson(e.map),
                        )
                        .toList(),
                  );

          openAIChatApi
              .createChatCompletionStream(messages, chat.temperature)
              .listen((event) {
            channel.sink.add(event.content);
          });
        },

        onError: (error) {
          throw Exception('Error on chat WebSocket');
        },

        // The client has disconnected.
        onDone: () async {
          return;
        },
      );
    },
  );

  return handler(context);
}

Future<dynamic> verifyIdToken(String idToken) async {
  const url =
      'https://www.googleapis.com/identitytoolkit/v3/relyingparty/getAccountInfo?key=AIzaSyAH_GgzhU1gnkjj6LGXo50JGXf302MmEg4';

  final response = await http.post(
    Uri.parse(url),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'idToken': idToken,
    }),
  );

  if (response.statusCode == 200) {
    // If the server returns a 200 OK response, then parse the JSON.
    final data = jsonDecode(response.body);

    // Now you can use the data
    return data;
  } else {
    // If the server does not return a 200 OK response,
    // then throw an exception.
    throw Exception('Failed to verify ID token');
  }
}

void checkForEnvs() {
  log('CHECKING FOR ENVS');
  if (Platform.environment['FIREBASE_API_KEY'] != null) {
    log('FIREBASE_API_KEY: IS DEFINED');
  }
  if (Platform.environment['FIREBASE_PROJECT_ID'] != null) {
    log('FIREBASE_PROJECT_ID: IS DEFINED');
  }
  if (Platform.environment['FIREBASE_APP_ID'] != null) {
    log('FIREBASE_APP_ID: IS DEFINED');
  }
}
