import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

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
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const CreatePlaylistScreen(),
                  ));
                },
                child: const Text('+ ساخت پلی‌لیست جدید',
                  style: TextStyle(color: Colors.pink, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreatePlaylistScreen extends StatefulWidget {
  const CreatePlaylistScreen({super.key});

  @override
  State<CreatePlaylistScreen> createState() => _CreatePlaylistScreenState();
}

class _CreatePlaylistScreenState extends State<CreatePlaylistScreen> {
  final _titleController = TextEditingController();
  final _dialogController = TextEditingController();
  bool _loading = false;
  String? _code;
  List<XFile> _images = [];
  final _picker = ImagePicker();

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _images.add(picked));
    }
  }

  Future<void> _create() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عنوان رو بنویس!')),
      );
      return;
    }
    setState(() => _loading = true);

    // ساخت پلی‌لیست
    final res = await http.post(
      Uri.parse('$baseUrl/api/playlists/create/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': _titleController.text,
        'dialog': _dialogController.text,
      }),
    );

    if (res.statusCode == 201) {
      final data = jsonDecode(res.body);
      final code = data['code'];

      // آپلود عکس‌ها
      for (final image in _images) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/api/playlists/$code/add-photo/'),
        );
        request.files.add(await http.MultipartFile.fromPath('image', image.path));
        await request.send();
      }

      setState(() {
        _loading = false;
        _code = code;
      });
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطا در ساخت پلی‌لیست!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ساخت پلی‌لیست'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_code != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.pink[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.pink),
                ),
                child: Column(
                  children: [
                    const Text('کد پلی‌لیست شما:',
                      style: TextStyle(fontSize: 16, color: Colors.pink)),
                    const SizedBox(height: 8),
                    Text(_code!,
                      style: const TextStyle(fontSize: 32,
                        fontWeight: FontWeight.bold, color: Colors.pink)),
                    const SizedBox(height: 8),
                    const Text('این کد رو به طرف مقابل بده',
                      style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ] else ...[
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'عنوان پلی‌لیست',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dialogController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'پیام عاشقانه',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo),
                label: const Text('اضافه کردن عکس'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              if (_images.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.all(4),
                      child: Image.file(File(_images[i].path), height: 100),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              _loading
                ? const CircularProgressIndicator(color: Colors.pink)
                : ElevatedButton(
                  onPressed: _create,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('ساخت پلی‌لیست'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class PlaylistScreen extends StatefulWidget {
  final Map data;
  const PlaylistScreen({super.key, required this.data});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final AudioPlayer _player = AudioPlayer();
  String? _playingUrl;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(String url) async {
    if (_playingUrl == url) {
      await _player.stop();
      setState(() => _playingUrl = null);
    } else {
      await _player.play(UrlSource(url));
      setState(() => _playingUrl = url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.data['photos'] as List? ?? [];
    final songs = widget.data['songs'] as List? ?? [];
    final dialog = widget.data['dialog'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.data['title'] ?? ''),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

            if (songs.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('🎵 موزیک‌ها',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pink)),
              ),
              ...songs.map((song) {
                final url = '$baseUrl${song['file']}';
                final isPlaying = _playingUrl == url;
                return ListTile(
                  leading: Icon(
                    isPlaying ? Icons.pause_circle : Icons.play_circle,
                    color: Colors.pink,
                    size: 40,
                  ),
                  title: Text(song['title']),
                  onTap: () => _togglePlay(url),
                );
              }),
            ],

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