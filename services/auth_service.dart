import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  Future<dynamic> verifyIdToken(String idToken, String apiKey) async {
    final url =
        'https://www.googleapis.com/identitytoolkit/v3/relyingparty/getAccountInfo?key=$apiKey';

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
}
