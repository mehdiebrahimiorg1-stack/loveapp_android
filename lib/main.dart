import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String baseUrl = 'https://loveapp-production-f89f.up.railway.app';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LoveApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
      ),
      home: const CodeScreen(),
    );
  }
}

class CodeScreen extends StatefulWidget {
  const CodeScreen({super.key});

  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen> {
  final _controller = TextEditingController();
  bool _loading = false;

  Future<void> _enter() async {
    setState(() => _loading = true);
    final code = _controller.text.trim().toUpperCase();
    final res = await http.get(Uri.parse('$baseUrl/api/playlists/$code/'));
    setState(() => _loading = false);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PlaylistScreen(data: data),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('کد اشتباهه!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink[50],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.music_note, size: 80, color: Colors.pink),
              const SizedBox(height: 20),
              const Text('کد خود را وارد کنید',
                style: TextStyle(fontSize: 20, color: Colors.pink)),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                  hintText: 'XXXXXX',
                ),
              ),
              const SizedBox(height: 20),
              _loading
                ? const CircularProgressIndicator(color: Colors.pink)
                : ElevatedButton(
                  onPressed: _enter,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('ورود'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlaylistScreen extends StatelessWidget {
  final Map data;
  const PlaylistScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final messages = data['messages'] as List;
    return Scaffold(
      appBar: AppBar(
        title: Text(data['title'] ?? ''),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        itemCount: messages.length,
        itemBuilder: (_, i) {
          final msg = messages[i];
          return Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg['song_title'] != '')
                    Text('🎵 ${msg['song_title']}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (msg['text'] != '')
                    Text(msg['text']),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}