import 'package:uuid/uuid.dart';

enum MessageRole { user, assistant }

class Message {
  final String id;
  final MessageRole role;
  String content;
  final DateTime timestamp;
  bool isStreaming;

  Message({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isStreaming = false,
  });

  factory Message.user(String text) {
    return Message(
      id: const Uuid().v4(),
      role: MessageRole.user,
      content: text,
      timestamp: DateTime.now(),
    );
  }

  factory Message.assistantStreaming() {
    return Message(
      id: const Uuid().v4(),
      role: MessageRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String? ?? 'user';
    final role = roleStr == 'assistant'
        ? MessageRole.assistant
        : MessageRole.user;

    String content = '';
    if (json['blocks'] != null) {
      final blocks = json['blocks'] as List;
      for (var block in blocks) {
        if (block['type'] == 'text') {
          // backend now sends block['content'] as a direct string
          final blockContent = block['content'];
          if (blockContent != null) {
             content += blockContent.toString();
          }
        }
      }
    }

    return Message(
      id: json['uuid'] as String? ?? const Uuid().v4(),
      role: role,
      content: content,
      timestamp: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
