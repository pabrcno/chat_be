import 'dart:convert';

import 'package:googleapis/secretmanager/v1.dart';
import 'package:googleapis_auth/auth_io.dart';

import '../domain/core/constants.dart';
import '../domain/core/enums.dart';
import '../domain/core/secrets.dart';

class SecretsService {
  Future<Secrets> getSecrets() async {
    final secretsClient = await clientViaApplicationDefaultCredentials(
      scopes: [
        SecretManagerApi.cloudPlatformScope,
      ],
    );

    final secretsManager = SecretManagerApi(secretsClient);

    final secrets = Secrets(
      openAIKey:
          await _getSecretValue(SecretNames.OPEN_AI_API_KEY, secretsManager),
      firebaseAPIKey:
          await _getSecretValue(SecretNames.FIREBASE_API_KEY, secretsManager),
      firebaseAppId:
          await _getSecretValue(SecretNames.FIREBASE_APP_ID, secretsManager),
      firebaseMessagingSenderId: await _getSecretValue(
          SecretNames.FIREBASE_MESSAGING_SENDER_ID, secretsManager),
    );

    return secrets;
  }

  Future<String> _getSecretValue(
    SecretNames secretName,
    SecretManagerApi secretsManager,
  ) async {
    try {
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
}
