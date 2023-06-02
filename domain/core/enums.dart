// ignore_for_file: constant_identifier_names

enum EMessageRole { system, user, assistant }

enum SecretNames {
  OPEN_AI_API_KEY,
  FIREBASE_API_KEY,
  FIREBASE_APP_ID,
  FIREBASE_MESSAGING_SENDER_ID,
}

extension SecretNamesExtension on SecretNames {
  String get name {
    switch (this) {
      case SecretNames.OPEN_AI_API_KEY:
        return 'OPEN_AI_API_KEY';
      case SecretNames.FIREBASE_API_KEY:
        return 'FIREBASE_API_KEY';
      case SecretNames.FIREBASE_APP_ID:
        return 'FIREBASE_APP_ID';
      case SecretNames.FIREBASE_MESSAGING_SENDER_ID:
        return 'FIREBASE_MESSAGING_SENDER_ID';
    }
  }
}
