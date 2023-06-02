class Secrets {
  Secrets({
    required this.openAIKey,
    required this.firebaseAPIKey,
    required this.firebaseAppId,
    required this.firebaseMessagingSenderId,
  });
  final String openAIKey;
  final String firebaseAPIKey;
  final String firebaseAppId;
  final String firebaseMessagingSenderId;
}
