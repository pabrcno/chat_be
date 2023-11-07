import 'dart:io';

import '../domain/core/enums.dart';
import '../domain/core/secrets.dart';

class SecretsService {
  Future<Secrets> getSecrets() async {
    // Instead of fetching secrets from Secret Manager, fetch from environment variables
    final secrets = Secrets(
      openAIKey: _getEnvVariable(SecretNames.OPEN_AI_API_KEY),
      firebaseAPIKey: _getEnvVariable(SecretNames.FIREBASE_API_KEY),
      firebaseAppId: _getEnvVariable(SecretNames.FIREBASE_APP_ID),
      firebaseMessagingSenderId:
          _getEnvVariable(SecretNames.FIREBASE_MESSAGING_SENDER_ID),
    );

    return secrets;
  }

  String _getEnvVariable(SecretNames secretName) {
    // Retrieve the environment variable using the secret name
    final secretValue = Platform.environment[secretName.name];
    if (secretValue == null) {
      throw Exception(
        'Environment variable for secret: ${secretName.name} not found.',
      );
    }
    return secretValue;
  }
}
