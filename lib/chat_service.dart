import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  // Use localhost for iOS simulator/Android emulator/Web/macOS as needed.
  // For macOS, localhost works.
  static const String _baseUrl = 'http://localhost:3000/api/chat';

  Stream<String> sendMessage(String content) async* {
    final request = http.Request('POST', Uri.parse(_baseUrl));
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({'content': content});

    final client = http.Client();
    try {
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Failed to send message: ${response.statusCode}');
      }

      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          // The backend sends "word " (with a trailing space).
          // We can just yield it as is, or trim if needed, but streaming usually implies appending.
          yield data;
        }
      }
    } catch (e) {
      throw Exception('Error sending message: $e');
    } finally {
      client.close();
    }
  }
}
