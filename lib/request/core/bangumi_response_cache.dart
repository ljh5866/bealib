import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'package:bealib/services/logging/logger.dart';

/// Bangumi 接口的轻量缓存（内存 + 磁盘）。
///
/// 背景：番剧数据统一走社区镜像 `api.kazumi.fyi`，本身延迟抖动较大
/// （实测 1–45s）。这里是只读缓存：同一请求 10 分钟内直接命中，
/// 过期数据在请求失败时仍可作为兜底返回（最多 24 小时），
/// 让首页推荐、番剧信息、角色/关联在重复进入时秒开。
class BangumiResponseCache {
  BangumiResponseCache._();

  static final BangumiResponseCache instance = BangumiResponseCache._();

  /// 新鲜期：命中后不发起网络请求。
  static const Duration freshTtl = Duration(minutes: 10);

  /// 兜底期：仅当网络失败时使用过期数据。
  static const Duration staleTtl = Duration(hours: 24);

  static const int _maxMemoryEntries = 80;

  final Map<String, _CacheEntry> _memory = <String, _CacheEntry>{};
  Directory? _directory;
  bool _directoryReady = false;

  Future<Directory?> _cacheDir() async {
    if (_directoryReady) return _directory;
    _directoryReady = true;
    try {
      final base = await getApplicationCacheDirectory();
      final dir = Directory('${base.path}/bangumi_api_cache');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _directory = dir;
    } catch (error) {
      BealibLogger().w('BangumiResponseCache: cache dir failed', error: error);
    }
    return _directory;
  }

  /// 与 [BangumiClient.get] 一致的缓存 key（无 query 时即 URL 本身）。
  static String keyFor(String url) => url;

  String _hash(String key) => sha256.convert(utf8.encode(key)).toString();

  /// 读取新鲜缓存；没有或过期返回 null。
  Future<dynamic> read(String key) async {
    final entry = _memory[key];
    if (entry != null && entry.isFresh) {
      return entry.data;
    }
    final disk = await _readDisk(key);
    if (disk != null && disk.isFresh) {
      _remember(key, disk);
      return disk.data;
    }
    return null;
  }

  /// 读取任意未超过 staleTtl 的缓存（用于网络失败兜底）。
  Future<dynamic> readStale(String key) async {
    final entry = _memory[key];
    if (entry != null && entry.isUsable) {
      return entry.data;
    }
    final disk = await _readDisk(key);
    if (disk != null && disk.isUsable) {
      _remember(key, disk);
      return disk.data;
    }
    return null;
  }

  Future<void> write(String key, dynamic data) async {
    final entry = _CacheEntry(data: data, storedAt: DateTime.now());
    _remember(key, entry);
    try {
      final dir = await _cacheDir();
      if (dir == null) return;
      final file = File('${dir.path}/${_hash(key)}.json');
      await file.writeAsString(
        jsonEncode(<String, dynamic>{
          'key': key,
          'stored_at': entry.storedAt.millisecondsSinceEpoch,
          'data': data,
        }),
        flush: true,
      );
    } catch (error) {
      BealibLogger().w('BangumiResponseCache: write failed', error: error);
    }
  }

  void _remember(String key, _CacheEntry entry) {
    if (_memory.length >= _maxMemoryEntries) {
      _memory.remove(_memory.keys.first);
    }
    _memory[key] = entry;
  }

  Future<_CacheEntry?> _readDisk(String key) async {
    try {
      final dir = await _cacheDir();
      if (dir == null) return null;
      final file = File('${dir.path}/${_hash(key)}.json');
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final storedAt = decoded['stored_at'];
      final data = decoded['data'];
      if (storedAt is! int || data == null) return null;
      return _CacheEntry(
        data: data,
        storedAt: DateTime.fromMillisecondsSinceEpoch(storedAt),
      );
    } catch (error) {
      BealibLogger().w('BangumiResponseCache: read failed', error: error);
      return null;
    }
  }
}

class _CacheEntry {
  _CacheEntry({required this.data, required this.storedAt});

  final dynamic data;
  final DateTime storedAt;

  bool get isFresh =>
      DateTime.now().difference(storedAt) <= BangumiResponseCache.freshTtl;

  bool get isUsable =>
      DateTime.now().difference(storedAt) <= BangumiResponseCache.staleTtl;
}
