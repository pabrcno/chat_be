// routes/ws.dart
import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_web_socket/dart_frog_web_socket.dart';
import 'package:firebase_dart/firebase_dart.dart';
import 'package:firedart/firedart.dart';
import 'package:googleapis/secretmanager/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import '../api/openAi/chat_api.dart';
import '../domain/api/chat/i_chat_api.dart';
import '../domain/models/chat/chat.dart';
import '../domain/models/message/message.dart';
import '../domain/models/message_request/message_request.dart';

const secretNames = [
  'OPEN_AI_API_KEY',
  'FIREBASE_API_KEY',
  'FIREBASE_APP_ID',
  'FIREBASE_MESSAGING_SENDER_ID',
];

// ignore: constant_identifier_names
const PROJECT_ID = 'topics-860b1';

Future<Response> onRequest(RequestContext context) async {
  final secrets = await getSecrets();

  final options = FirebaseOptions(
    apiKey: secrets[secretNames[1]] ?? '',
    projectId: PROJECT_ID,
    appId: secrets[secretNames[2]] ?? '',
    messagingSenderId: secrets[secretNames[3]] ?? '',
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
          await verifyIdToken(
            messageRequest.userToken,
            secrets['FIREBASE_API_KEY'] ?? '',
          );
          final IChatApi openAIChatApi =
              OpenAIChatApi(apiKey: secrets['OPEN_AI_API_KEY']);

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

Future<dynamic> verifyIdToken(String idToken, String key) async {
  final url =
      'https://www.googleapis.com/identitytoolkit/v3/relyingparty/getAccountInfo?key=$key';

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

Future<Map<String, String?>> getSecrets() async {
  final secretsClient = await clientViaApplicationDefaultCredentials(
    scopes: [
      SecretManagerApi.cloudPlatformScope,
    ],
  );

  final secretsManager = SecretManagerApi(secretsClient);

  final secrets = <String, String?>{};

  for (final secretName in secretNames) {
    final secretResponse = await secretsManager.projects.secrets.versions
        .access('projects/$PROJECT_ID/secrets/$secretName/versions/latest');

    final secretValue = utf8
        .decode(base64Decode(secretResponse.payload?.data ?? ''))
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .replaceAll('\t', '');
    secrets[secretName] = secretValue;
  }

  return secrets;
}
