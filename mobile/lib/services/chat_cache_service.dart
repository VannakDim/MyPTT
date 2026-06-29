import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/chat_message.model.dart';

class ChatCacheService {
  static final ChatCacheService _instance = ChatCacheService._internal();
  factory ChatCacheService() => _instance;
  ChatCacheService._internal();

  Future<Directory> get _cacheDirectory async {
    final docDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${docDir.path}/chat_caches');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  File _getCacheFile(Directory dir, int groupId) {
    return File('${dir.path}/group_$groupId.json');
  }

  // ១. ទាញយកសារដែលបានរក្សាទុកក្នុង Local Cache
  Future<List<ChatMessage>> getCachedMessages(int groupId, String currentUsername) async {
    try {
      final dir = await _cacheDirectory;
      final file = _getCacheFile(dir, groupId);
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((j) => ChatMessage.fromJson(j, currentUsername)).toList();
    } catch (e) {
      print("[ChatCache] Error reading cache: $e");
      return [];
    }
  }

  // ២. រក្សាទុកសារថ្មីចូលទៅក្នុង Local Cache (ដោយមិនជាន់គ្នា)
  Future<void> cacheMessages(int groupId, List<ChatMessage> newMessages) async {
    if (newMessages.isEmpty) return;
    try {
      final dir = await _cacheDirectory;
      final file = _getCacheFile(dir, groupId);
      
      List<Map<String, dynamic>> cachedJson = [];
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          final decoded = jsonDecode(content);
          if (decoded is List) {
            cachedJson = List<Map<String, dynamic>>.from(decoded);
          }
        } catch (_) {
          // Ignore corruption
        }
      }

      // Merge messages by unique ID to prevent duplication
      final Map<dynamic, Map<String, dynamic>> mergedMap = {};
      
      // Load old messages into map
      for (var msg in cachedJson) {
        final id = msg['id'];
        if (id != null) {
          mergedMap[id] = msg;
        } else {
          // Fallback if no ID (use text + timestamp combination key)
          final key = "${msg['sender']}_${msg['created_at']}_${msg['text']}";
          mergedMap[key] = msg;
        }
      }

      // Overwrite/insert new messages
      for (var msg in newMessages) {
        final jsonRepresentation = msg.toJson();
        final id = msg.id;
        if (id != null) {
          mergedMap[id] = jsonRepresentation;
        } else {
          final key = "${msg.sender}_${msg.createdAt?.toIso8601String()}_${msg.text}";
          mergedMap[key] = jsonRepresentation;
        }
      }

      // Convert back to list and sort by id or timestamp descending (newest first)
      final List<Map<String, dynamic>> mergedList = mergedMap.values.toList();
      mergedList.sort((a, b) {
        final aId = a['id'];
        final bId = b['id'];
        if (aId != null && bId != null) {
          return bId.compareTo(aId); // Descending ID order
        }
        final aTime = a['created_at'] != null ? DateTime.tryParse(a['created_at']) : null;
        final bTime = b['created_at'] != null ? DateTime.tryParse(b['created_at']) : null;
        if (aTime != null && bTime != null) {
          return bTime.compareTo(aTime);
        }
        return 0;
      });

      // Limit each channel cache size to maximum 300 messages to keep file operations light
      final trimmedList = mergedList.take(300).toList();

      await file.writeAsString(jsonEncode(trimmedList), flush: true);
      
      // Run background cleanup asynchronously
      _checkAndCleanupCache(dir);
    } catch (e) {
      print("[ChatCache] Error writing cache: $e");
    }
  }

  // ៣. ពិនិត្យទំហំ Cache សរុប បើលើសពី 1GB ត្រូវលុប Cache ចាស់ៗចោល
  Future<void> _checkAndCleanupCache(Directory dir) async {
    try {
      final List<FileSystemEntity> files = await dir.list().toList();
      int totalSizeBytes = 0;
      final List<File> cacheFiles = [];

      for (var entity in files) {
        if (entity is File && entity.path.endsWith('.json')) {
          totalSizeBytes += await entity.length();
          cacheFiles.add(entity);
        }
      }

      final int oneGb = 1024 * 1024 * 1024;
      if (totalSizeBytes > oneGb) {
        print("[ChatCache] Cache size ($totalSizeBytes bytes) exceeds 1GB limit! Purging old caches...");
        // Sort files by modified time (oldest modified first)
        final Map<File, DateTime> fileTimes = {};
        for (var file in cacheFiles) {
          fileTimes[file] = await file.lastModified();
        }
        cacheFiles.sort((a, b) => fileTimes[a]!.compareTo(fileTimes[b]!));

        // Delete oldest files until we are below 700MB (734,003,200 bytes)
        final int targetSize = (700 * 1024 * 1024);
        for (var file in cacheFiles) {
          if (totalSizeBytes <= targetSize) break;
          final int length = await file.length();
          await file.delete();
          totalSizeBytes -= length;
          print("[ChatCache] Deleted old cache file: ${file.path}");
        }
      }
    } catch (e) {
      print("[ChatCache] Error cleaning up cache: $e");
    }
  }
}
