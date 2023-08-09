// routes/ws.dart
import 'dart:convert';
import 'dart:developer';

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_web_socket/dart_frog_web_socket.dart';

import '../api/openAi/chat_api.dart';
import '../domain/api/chat/i_chat_api.dart';
import '../domain/core/secrets.dart';
import '../domain/models/message_request/message_request.dart';
import '../domain/models/repo/i_chat_repo.dart';
import '../repo/firestore_chat_repo.dart';
import '../services/auth_service.dart';
import '../services/secrets_service.dart';

Future<Response> onRequest(RequestContext context) async {
  final secrets = await SecretsService().getSecrets();

  final repo = await FirestoreStore.create(secrets);
  // testing gpt-4 model for now, to test cost increase
  final IChatApi chatApi =
      OpenAIChatApi(apiKey: secrets.openAIKey, model: 'gpt-4');
  final authService = AuthService();
  final handler =
      createHandler(secrets, repo, chatApi, authService.verifyIdToken);

  return handler(context);
}

Handler createHandler(
  Secrets secrets,
  IChatRepo repo,
  IChatApi chatApi,
  Future<dynamic> Function(String idToken, String apiKey) tokenVerifier,
) =>
    webSocketHandler((channel, protocol) {
      channel.stream.listen(
        (event) async {
          try {
            final json = jsonDecode(event as String) as Map<String, dynamic>;
            final messageRequest = MessageRequest.fromJson(json);
            final verificationData = await tokenVerifier(
              messageRequest.userToken,
              secrets.firebaseAPIKey,
            );

            log(messageRequest.toString());

            // ignore: avoid_dynamic_calls
            if (verificationData == null || verificationData['error'] != null) {
              throw Exception('ID token verification failed.');
            }

            chatApi
                .createChatCompletionStream(
              messageRequest.messages,
              messageRequest.temperature,
            )
                .listen((message) {
              if (message.finishReason != null) {
                channel.sink.close();
              }
              channel.sink.add(jsonEncode(message.message.toJson()));
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
          log('END OF STREAM');
        },
      );
    });
