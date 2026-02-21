import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import '../config/app_config.dart';
import '../models/message.dart';
import 'package:http/http.dart' as http;

class ChatScreen extends StatefulWidget {
  final String? threadUuid;

  const ChatScreen({super.key, this.threadUuid});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Message> messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  final String backendUrl = AppConfig.backendUrl;
  String? currentThreadUuid;

  @override
  void initState() {
    super.initState();
    currentThreadUuid = widget.threadUuid;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (currentThreadUuid == null) {
      return; // No history to load
    }
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/threads/$currentThreadUuid/messages'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          messages.clear();
          messages.addAll(
            data.map((json) => Message.fromJson(json as Map<String, dynamic>)),
          );
        });
        _scrollToBottom();
      } else {
        debugPrint('Failed to load history: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hive')),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isUser = message.role == MessageRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content.isEmpty ? '...' : message.content,
              style: const TextStyle(fontSize: 16),
            ),
            if (message.isStreaming)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: _isSending ? null : _sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _isSending
                ? null
                : () => _sendMessage(_textController.text),
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      messages.add(Message.user(text));
      _isSending = true;
    });

    _textController.clear();
    _scrollToBottom();

    final assistantMessage = Message.assistantStreaming();
    setState(() {
      messages.add(assistantMessage);
    });

    await _streamResponse(text, assistantMessage);

    setState(() {
      assistantMessage.isStreaming = false;
      _isSending = false;
    });
  }

  Future<void> _streamResponse(
    String userMessage,
    Message assistantMessage,
  ) async {
    try {
      final requestUrl = '$backendUrl/chat';
      debugPrint('Requesting SSE from: $requestUrl');
      SSEClient.subscribeToSSE(
        method: SSERequestType.POST,
        url: requestUrl,
        header: {'Content-Type': 'application/json'},
        body: {
          'content':
              userMessage, // Updated per user comment "app must send {content: string} as message"
          if (currentThreadUuid != null) 'threadUuid': currentThreadUuid,
        },
      ).listen(
        (event) {
          try {
            final dataStr = event.data;
            if (dataStr == null || dataStr.isEmpty) return;

            // Try block in case backend payload isn't what we expect
            final data = jsonDecode(dataStr);

            if (data is Map &&
                data.containsKey('threadUuid') &&
                currentThreadUuid == null) {
              setState(() {
                currentThreadUuid = data['threadUuid'];
              });
            }

            if (event.event == 'message' || event.event == 'text') {
              // Hono or standard SSE usually sends event empty or just streams data
              // If data has content field
              if (data is Map && data.containsKey('content')) {
                setState(() {
                  assistantMessage.content += data['content'] ?? '';
                });
              } else if (data is String) {
                // Sometime chunk is just the string directly
                setState(() {
                  assistantMessage.content += data;
                });
              }
              _scrollToBottom();
            } else if (event.event == 'messageEnd') {
              setState(() {
                assistantMessage.isStreaming = false;
              });
            } else if (event.event == '') {
              // Many robust stream implementations from an LLM just send the token as data, no explicit event key
              if (data is Map && data.containsKey('content')) {
                setState(() {
                  assistantMessage.content += data['content'] ?? '';
                });
              } else if (data is String) {
                setState(() {
                  assistantMessage.content += data;
                });
              }
              _scrollToBottom();
            }
          } catch (e) {
            // Not json decoded? Sometimes standard text streams are just raw string.
            setState(() {
              assistantMessage.content += event.data ?? '';
            });
            _scrollToBottom();
          }
        },
        onError: (error) {
          debugPrint('SSE Error: $error');
          setState(() {
            assistantMessage.content = 'Sorry, something went wrong.';
            assistantMessage.isStreaming = false;
          });
        },
      );
    } catch (e) {
      debugPrint('Exception: $e');
      setState(() {
        assistantMessage.content = 'Failed to connect to server.';
        assistantMessage.isStreaming = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    SSEClient.unsubscribeFromSSE();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
