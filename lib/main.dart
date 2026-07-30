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
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink)),
      home: const CodeScreen(),
    );
  }
}

// ─────────────────────────────────────────────
// صفحه ورود کد
// ─────────────────────────────────────────────
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
        _snack('کد اشتباهه!');
      }
    } catch (e) {
      setState(() => _loading = false);
      _snack('خطا: $e');
    }
  }

  void _snack(String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink[50],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite, size: 80, color: Colors.pink),
              const SizedBox(height: 20),
              const Text('کد خود را وارد کنید',
                style: TextStyle(fontSize: 20, color: Colors.pink)),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CreatePlaylistScreen())),
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

// ─────────────────────────────────────────────
// صفحه ساخت پلی‌لیست (اصلاح‌شده)
// ─────────────────────────────────────────────
class CreatePlaylistScreen extends StatefulWidget {
  const CreatePlaylistScreen({super.key});
  @override
  State<CreatePlaylistScreen> createState() => _CreatePlaylistScreenState();
}

class _CreatePlaylistScreenState extends State<CreatePlaylistScreen> {
  final _titleController = TextEditingController();
  final _dialogController = TextEditingController();
  final _songTitleController = TextEditingController();
  bool _loading = false;
  String? _code;
  List<XFile> _images = [];
  XFile? _song;
  final _picker = ImagePicker();
  String _status = '';

  void _snack(String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _pickImages() async {
    // درخواست مجوز و انتخاب چند عکس
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() => _images = picked);
    }
  }

  Future<void> _pickSong() async {
    // انتخاب فایل موزیک از گالری
    final picked = await _picker.pickMedia();
    if (picked != null) {
      // فقط فایل‌های صوتی قبول میکنیم
      final ext = picked.path.split('.').last.toLowerCase();
      if (['mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac'].contains(ext)) {
        setState(() => _song = picked);
      } else {
        _snack('لطفاً یه فایل موزیک انتخاب کن (mp3, wav, ...)');
      }
    }
  }

  Future<void> _create() async {
    if (_titleController.text.isEmpty) {
      _snack('عنوان رو بنویس!');
      return;
    }
    setState(() { _loading = true; _status = 'در حال ساخت پلی‌لیست...'; });

    try {
      // مرحله ۱: ساخت پلی‌لیست
      final res = await http.post(
        Uri.parse('$baseUrl/api/playlists/create/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': _titleController.text,
          'dialog': _dialogController.text,
        }),
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode != 201) {
        _snack('خطا در ساخت پلی‌لیست: ${res.body}');
        setState(() => _loading = false);
        return;
      }

      final data = jsonDecode(res.body);
      final code = data['code'];

      // مرحله ۲: آپلود عکس‌ها
      for (int i = 0; i < _images.length; i++) {
        setState(() => _status = 'آپلود عکس ${i + 1} از ${_images.length}...');
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/api/playlists/$code/add-photo/'),
        );
        request.files.add(
          await http.MultipartFile.fromPath('image', _images[i].path)
        );
        // caption خالی هم ارسال میکنیم
        request.fields['caption'] = '';
        final response = await request.send().timeout(const Duration(seconds: 30));
        if (response.statusCode != 201) {
          final body = await response.stream.bytesToString();
          _snack('خطا در آپلود عکس ${i + 1}: $body');
        }
      }

      // مرحله ۳: آپلود موزیک
      if (_song != null) {
        setState(() => _status = 'آپلود موزیک...');
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/api/playlists/$code/add-song/'),
        );
        request.files.add(
          await http.MultipartFile.fromPath('file', _song!.path)
        );
        request.fields['title'] = _songTitleController.text.isEmpty
          ? 'موزیک'
          : _songTitleController.text;
        final response = await request.send().timeout(const Duration(seconds: 60));
        if (response.statusCode != 201) {
          final body = await response.stream.bytesToString();
          _snack('خطا در آپلود موزیک: $body');
        }
      }

      setState(() {
        _loading = false;
        _code = code;
        _status = '';
      });

    } catch (e) {
      setState(() { _loading = false; _status = ''; });
      _snack('خطا: $e');
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_code != null) ...[
              // نمایش کد موفق
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.pink[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.pink, width: 2),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 50),
                    const SizedBox(height: 12),
                    const Text('پلی‌لیست ساخته شد! 🎉',
                      style: TextStyle(fontSize: 18, color: Colors.pink)),
                    const SizedBox(height: 12),
                    const Text('کد پلی‌لیست:',
                      style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(_code!,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.pink,
                        letterSpacing: 8,
                      )),
                    const SizedBox(height: 8),
                    const Text('این کد رو به طرف مقابل بده ❤️',
                      style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ] else ...[
              // فرم ساخت پلی‌لیست
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'عنوان پلی‌لیست',
                  prefixIcon: const Icon(Icons.title, color: Colors.pink),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dialogController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'پیام عاشقانه 💬',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // بخش عکس
              const Text('📸 عکس‌ها', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.photo_library, color: Colors.pink),
                label: Text(_images.isEmpty
                  ? 'انتخاب عکس از گالری'
                  : '${_images.length} عکس انتخاب شده'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.pink,
                  side: const BorderSide(color: Colors.pink),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              if (_images.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    itemBuilder: (_, i) => Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: Image.file(File(_images[i].path),
                            height: 100, width: 100, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 0, right: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _images.removeAt(i)),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.red,
                              child: Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // بخش موزیک
              const Text('🎵 موزیک', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickSong,
                icon: const Icon(Icons.music_note, color: Colors.pink),
                label: Text(_song == null
                  ? 'انتخاب موزیک از گالری'
                  : _song!.path.split('/').last),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.pink,
                  side: const BorderSide(color: Colors.pink),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              if (_song != null) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _songTitleController,
                  decoration: InputDecoration(
                    labelText: 'نام موزیک',
                    prefixIcon: const Icon(Icons.music_note, color: Colors.pink),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // وضعیت آپلود
              if (_loading) ...[
                const CircularProgressIndicator(color: Colors.pink),
                const SizedBox(height: 8),
                Text(_status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.pink)),
              ] else
                ElevatedButton(
                  onPressed: _create,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('ساخت پلی‌لیست ❤️', fontSize: 18),
                    style: TextStyle(fontSize: 18)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// صفحه نمایش پلی‌لیست (با عکس مات)
// ─────────────────────────────────────────────
class PlaylistScreen extends StatefulWidget {
  final Map data;
  const PlaylistScreen({super.key, required this.data});
  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final AudioPlayer _player = AudioPlayer();
  String? _playingUrl;
  final Set<int> _unlockedPhotos = {};
  bool _songsUnlocked = false;

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

  void _unlockPhoto(int index) {
    setState(() => _unlockedPhotos.add(index));
  }

  void _unlockSongs() {
    setState(() => _songsUnlocked = true);
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

            // ── عکس‌ها با blur ──
            if (photos.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('📸 عکس‌ها',
                  style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.bold, color: Colors.pink)),
              ),
              ...photos.asMap().entries.map((entry) {
                final i = entry.key;
                final photo = entry.value;
                final isUnlocked = _unlockedPhotos.contains(i);
                final imgUrl = '$baseUrl${photo['image']}';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  clipBehavior: Clip.hardEdge,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // عکس اصلی
                      Image.network(
                        imgUrl,
                        width: double.infinity,
                        height: 250,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image, size: 100),
                      ),
                      // لایه blur اگه قفله
                      if (!isUnlocked)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () => _unlockPhoto(i),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock, color: Colors.white, size: 40),
                                  SizedBox(height: 8),
                                  Text('برای دیدن عکس ضربه بزنید',
                                    style: TextStyle(color: Colors.white, fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],

            // ── موزیک‌ها ──
            if (songs.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('🎵 موزیک‌ها',
                  style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.bold, color: Colors.pink)),
              ),
              if (!_songsUnlocked)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.lock, color: Colors.pink, size: 40),
                    title: const Text('برای گوش دادن ضربه بزنید'),
                    onTap: _unlockSongs,
                  ),
                )
              else
                ...songs.map((song) {
                  final url = '$baseUrl${song['file']}';
                  final isPlaying = _playingUrl == url;
                  return ListTile(
                    leading: Icon(
                      isPlaying ? Icons.pause_circle : Icons.play_circle,
                      color: Colors.pink, size: 40,
                    ),
                    title: Text(song['title']),
                    onTap: () => _togglePlay(url),
                  );
                }),
            ],

            // ── پیام ──
            if (dialog != '') ...[
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('💬 پیام',
                  style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.bold, color: Colors.pink)),
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

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}