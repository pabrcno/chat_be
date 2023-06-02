// routes/ws.dart
import 'dart:convert';
import 'dart:developer';

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_web_socket/dart_frog_web_socket.dart';
import 'package:firebase_dart/firebase_dart.dart';
import 'package:firedart/firedart.dart';
import 'package:googleapis/identitytoolkit/v3.dart';
import 'package:googleapis/secretmanager/v1.dart';
import 'package:googleapis_auth/auth_io.dart';

import '../api/openAi/chat_api.dart';
import '../domain/api/chat/i_chat_api.dart';
import '../domain/models/chat/chat.dart';
import '../domain/models/message/message.dart';
import '../domain/models/message_request/message_request.dart';

Future<Response> onRequest(RequestContext context) async {
  final secrets = await getSecrets();

  final options = FirebaseOptions(
    apiKey: secrets['FIREBASE_API_KEY'] ?? '',
    projectId: secrets['FIREBASE_PROJECT_ID'] ?? '',
    appId: secrets['FIREBASE_APP_ID'] ?? '',
    messagingSenderId: secrets['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
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
          final IChatApi openAIChatApi =
              OpenAIChatApi(apiKey: secrets['OPENAI_API_KEY']);

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
  final client = await clientViaApplicationDefaultCredentials(
    scopes: [IdentityToolkitApi.cloudPlatformScope],
  );
  final identityToolkitApi = IdentityToolkitApi(client);

  try {
    // Make the API request
    final response = await identityToolkitApi.relyingparty.getAccountInfo(
      IdentitytoolkitRelyingpartyGetAccountInfoRequest(idToken: idToken),
    );

    // Extract and return the response data
    return response.toJson();
  } catch (e) {
    // Handle any errors
    throw Exception('Failed to verify ID token: $e');
  }
}

Future<Map<String, String?>> getSecrets() async {
  print('getSecrets');
  final secretNames = [
    'OPEN_AI_API_KEY',
    'FIREBASE_API_KEY',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_APP_ID',
    'FIREBASE_MESSAGING_SENDER_ID',
  ];

  final secretsClient = await clientViaApplicationDefaultCredentials(
    scopes: [
      SecretManagerApi.cloudPlatformScope,
    ],
  );

  final secretsManager = SecretManagerApi(secretsClient);

  final secrets = <String, String?>{};
  for (final secretName in secretNames) {
    try {
      final secretResponse =
          await secretsManager.projects.secrets.versions.access(secretName);

      final secretValue = secretResponse.payload?.data;
      secrets[secretName] = secretValue;
    } catch (e) {
      log(e.toString());
    }
  }

  return secrets;
}
