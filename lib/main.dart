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
    final code = _controller.text.trim();
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/playlists/$code/'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
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
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا: $e')),
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
                keyboardType: TextInputType.number,
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
                    minimumSize: const Size(double.infinity, 50),
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
    final photos = data['photos'] as List? ?? [];
    final songs = data['songs'] as List? ?? [];
    final dialog = data['dialog'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(data['title'] ?? ''),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // بخش عکس‌ها
            if (photos.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('📸 عکس‌ها',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pink)),
              ),
              ...photos.map((photo) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        '$baseUrl${photo['image']}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => 
                          const Icon(Icons.broken_image, size: 100),
                      ),
                    ),
                    if (photo['caption'] != '')
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(photo['caption']),
                      ),
                  ],
                ),
              )),
            ],

            // بخش موزیک‌ها
            if (songs.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('🎵 موزیک‌ها',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pink)),
              ),
              ...songs.map((song) => ListTile(
                leading: const Icon(Icons.music_note, color: Colors.pink),
                title: Text(song['title']),
              )),
            ],

            // بخش دیالوگ
            if (dialog != '') ...[
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('💬 پیام',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pink)),
              ),
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.pink[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.pink),
                ),
                child: Text(dialog, style: const TextStyle(fontSize: 16)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}