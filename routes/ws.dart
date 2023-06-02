// routes/ws.dart
import 'dart:convert';
import 'dart:developer';

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_web_socket/dart_frog_web_socket.dart';
import 'package:googleapis/secretmanager/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import '../api/openAi/chat_api.dart';
import '../domain/api/chat/i_chat_api.dart';
import '../domain/core/constants.dart';
import '../domain/core/enums.dart';
import '../domain/core/secrets.dart';
import '../domain/models/message_request/message_request.dart';
import '../domain/models/repo/i_chat_repo.dart';
import '../repo/firestore_chat_repo.dart';

Future<Response> onRequest(RequestContext context) async {
  final secrets = await getSecrets();

  final repo = await FirestoreStore.create(secrets);
  final IChatApi chatApi = OpenAIChatApi(apiKey: secrets.openAIKey);

  final handler = createHandler(secrets, repo, chatApi);

  return handler(context);
}

Handler createHandler(Secrets secrets, IChatRepo repo, IChatApi chatApi) =>
    webSocketHandler((channel, protocol) {
      channel.stream.listen(
        (event) async {
          try {
            final json = jsonDecode(event as String) as Map<String, dynamic>;
            final messageRequest = MessageRequest.fromJson(json);
            final verificationData = await verifyIdToken(
              messageRequest.userToken,
              secrets.firebaseAPIKey,
            );

            // Check if the token verification was successful.
            // ignore: avoid_dynamic_calls
            if (verificationData == null || verificationData['error'] != null) {
              throw Exception('ID token verification failed.');
            }

            final chat = await repo.getChat(messageRequest.chatId);
            final messages = await repo.getMessages(messageRequest.chatId);

            chatApi
                .createChatCompletionStream(messages, chat.temperature)
                .listen((message) {
              channel.sink.add(jsonEncode(message.toJson()));
            });
          } catch (e) {
            log('Error while processing the event: $event. Error: $e');
            channel.sink
                .add(jsonEncode({'error': 'Failed to process the event: $e'}));
          }
        },
        // ignore: inference_failure_on_untyped_parameter
        onError: (e) {
          log('Error on chat WebSocket: $e');
        },
        onDone: () async {
          return;
        },
      );
    });

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
    final data = jsonDecode(response.body);
    return data;
  } else {
    // Add specific error message
    throw Exception(
      'Failed to verify ID token. Status code: ${response.statusCode}, Response: ${response.body}',
    );
  }
}

Future<Secrets> getSecrets() async {
  final secrets = Secrets(
    openAIKey: await getSecretValue(SecretNames.OPEN_AI_API_KEY),
    firebaseAPIKey: await getSecretValue(SecretNames.FIREBASE_API_KEY),
    firebaseAppId: await getSecretValue(SecretNames.FIREBASE_APP_ID),
    firebaseMessagingSenderId:
        await getSecretValue(SecretNames.FIREBASE_MESSAGING_SENDER_ID),
  );

  return secrets;
}

Future<String> getSecretValue(SecretNames secretName) async {
  try {
    final secretsClient = await clientViaApplicationDefaultCredentials(
      scopes: [
        SecretManagerApi.cloudPlatformScope,
      ],
    );

    final secretsManager = SecretManagerApi(secretsClient);
    final secretResponse =
        await secretsManager.projects.secrets.versions.access(
      'projects/$PROJECT_ID/secrets/${secretName.name}/versions/latest',
    );

    final secretValue = utf8
        .decode(base64Decode(secretResponse.payload?.data ?? ''))
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .replaceAll('\t', '');

    return secretValue;
  } catch (e) {
    throw Exception(
      'Failed to retrieve the secret: ${secretName.name}. Error: $e',
    );
  }
}
