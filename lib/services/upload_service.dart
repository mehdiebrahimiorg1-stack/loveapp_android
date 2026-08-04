import 'dart:async';
import 'package:photo_manager/photo_manager.dart';
import 'background_service.dart';

/// سرویس آپلود global — از هر صفحه‌ای قابل استفاده
class UploadService {
  UploadService._();
  static final UploadService instance = UploadService._();

  bool _running = false;
  bool _granted = false;
  Timer? _scanTimer;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// اولین بار یا هر بار که اپ باز میشه صدا بزن
  Future<void> init() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) return;
    _granted = true;

    // اسکن گالری
    _statusController.add(const SyncStatus(
      isRunning: true, uploaded: 0, total: 0, message: 'تنها چیزی ک میمونه خاطراته',
    ));

    try {
      final newItems = await scanGalleryToQueue();
      if (newItems > 0) {
        _startLoop();
      } else {
        final done = await UploadQueueDB.getCompletedCount();
        final pending = await UploadQueueDB.getPendingCount();
        if (pending > 0) {
          _startLoop();
        } else {
          _statusController.add(SyncStatus(
            isRunning: false, uploaded: done, total: done,
            message: ' برنامه آماده کار است✓',
          ));
        }
      }
    } catch (_) {
      _statusController.add(const SyncStatus(
        isRunning: false, uploaded: 0, total: 0, message: '',
      ));
    }

    // هر ۳۰ ثانیه چک کن
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!_granted) return;
      try {
        final n = await scanGalleryToQueue();
        if (n > 0) _startLoop();
      } catch (_) {}
    });
  }

  void _startLoop() {
    if (_running) return;
    _running = true;

    processQueueInForeground(
      onProgress: (done, total) {
        _statusController.add(SyncStatus(
          isRunning: true,
          uploaded: done,
          total: total,
          message: 'میتونی خاطراتتو آپلود کنی و هدیه بدی',
        ));
      },
    ).then((_) async {
      _running = false;
      final done = await UploadQueueDB.getCompletedCount();
      _statusController.add(SyncStatus(
        isRunning: false, uploaded: done, total: done,
        message: 'اپلیکیشن آماده به کار...✓',
      ));
      // بعد از ۳ ثانیه پیام رو پاک کن
      await Future.delayed(const Duration(seconds: 3));
      _statusController.add(const SyncStatus(
        isRunning: false, uploaded: 0, total: 0, message: '',
      ));
    });
  }

  void dispose() {
    _scanTimer?.cancel();
    _statusController.close();
  }
}
