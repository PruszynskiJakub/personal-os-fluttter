import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/thread.dart';
import '../chat_screen.dart';

class ThreadListScreen extends StatefulWidget {
  const ThreadListScreen({super.key});

  @override
  State<ThreadListScreen> createState() => _ThreadListScreenState();
}

class _ThreadListScreenState extends State<ThreadListScreen> {
  final String backendUrl = AppConfig.backendUrl;
  List<Thread> _threads = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThreads();
  }

  Future<void> _loadThreads() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$backendUrl/threads'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _threads = data
              .map((json) => Thread.fromJson(json as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      } else {
        debugPrint('Failed to load threads: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading threads: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadThreads),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _threads.isEmpty
          ? const Center(child: Text('No conversations yet. Start a new chat!'))
          : ListView.builder(
              itemCount: _threads.length,
              itemBuilder: (context, index) {
                final thread = _threads[index];
                return ListTile(
                  title: Text(thread.title),
                  subtitle: Text(
                    '${thread.createdAt.toLocal().toString().split('.')[0]}',
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ChatScreen(threadUuid: thread.uuid),
                      ),
                    );
                    _loadThreads(); // Refresh when returning
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatScreen()),
          );
          _loadThreads(); // Refresh when returning
        },
        child: const Icon(Icons.chat),
      ),
    );
  }
}
