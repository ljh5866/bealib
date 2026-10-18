import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:bealib/modules/bangumi/bangumi_item.dart';
import 'package:bealib/modules/bangumi/bangumi_tag.dart';
import 'package:bealib/modules/search/plugin_search_module.dart';
import 'package:bealib/request/core/dio_factory.dart';
import 'package:bealib/services/logging/logger.dart';

/// 离线番剧检索兜底。
///
/// 镜像搜索需要 KAZUMI_APPID / KAZUMI_KEY 签名（官方 CI 注入，本地构建没有），
/// 因此这里用公开的 bangumi-data 数据集做本地检索：
/// - 首次搜索时下载并缓存到应用缓存目录（约 7.9MB，之后走本地缓存）；
/// - 仅用于「按标题找番剧」，评分/简介等仍由详情接口补齐。
class BangumiLocalSearch {
  BangumiLocalSearch._();

  static final BangumiLocalSearch instance = BangumiLocalSearch._();

  static const String _datasetUrl =
      'https://cdn.jsdelivr.net/npm/bangumi-data@0.3.231/dist/data.json';
  static const String _datasetFileName = 'bangumi-data-0.3.231.json';
  static const Duration _cacheMaxAge = Duration(days: 7);

  static const Set<String> _animeTypes = {'tv', 'web', 'ova', 'movie'};

  List<_LocalSubject>? _subjects;
  Future<List<_LocalSubject>>? _loading;

  Future<List<_LocalSubject>> _ensureLoaded() {
    final cached = _subjects;
    if (cached != null) return Future.value(cached);
    return _loading ??= _load();
  }

  Future<List<_LocalSubject>> _load() async {
    try {
      final String? raw = await _readCache();
      final sources = <String>[];
      if (raw != null) sources.add(raw);
      if (sources.isEmpty) {
        final downloaded = await _download();
        if (downloaded != null) sources.add(downloaded);
      }
      if (sources.isEmpty) return <_LocalSubject>[];
      final parsed = _parse(sources.first);
      _subjects = parsed;
      return parsed;
    } finally {
      _loading = null;
    }
  }

  Future<File?> _cacheFile() async {
    try {
      final dir = await getApplicationCacheDirectory();
      final file = File('${dir.path}/$_datasetFileName');
      if (await file.exists()) return file;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readCache() async {
    try {
      final file = await _cacheFile();
      if (file == null) return null;
      final stat = await file.stat();
      if (DateTime.now().difference(stat.modified) > _cacheMaxAge) {
        return null;
      }
      return await file.readAsString();
    } catch (error) {
      BealibLogger().w('BangumiLocalSearch: read cache failed', error: error);
      return null;
    }
  }

  Future<String?> _download() async {
    try {
      final response = await DioFactory.apiDio.get<String>(
        _datasetUrl,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 90),
        ),
      );
      final data = response.data;
      if (data == null || data.isEmpty) return null;
      try {
        final dir = await getApplicationCacheDirectory();
        final file = File('${dir.path}/$_datasetFileName');
        await file.writeAsString(data, flush: true);
      } catch (error) {
        BealibLogger()
            .w('BangumiLocalSearch: write cache failed', error: error);
      }
      return data;
    } catch (error) {
      BealibLogger().w('BangumiLocalSearch: download failed', error: error);
      return null;
    }
  }

  List<_LocalSubject> _parse(String raw) {
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['items'] is! List) return <_LocalSubject>[];
    final result = <_LocalSubject>[];
    for (final dynamic item in decoded['items'] as List) {
      if (item is! Map) continue;
      final type = (item['type'] ?? '').toString();
      if (!_animeTypes.contains(type)) continue;
      final int? bgmId = _extractBgmId(item);
      if (bgmId == null) continue;
      final String title = (item['title'] ?? '').toString().trim();
      if (title.isEmpty) continue;
      final List<String> chineseTitles = _extractTranslatedTitles(item);
      result.add(
        _LocalSubject(
          id: bgmId,
          title: title,
          translatedTitles: chineseTitles,
          begin: (item['begin'] ?? '').toString(),
        ),
      );
    }
    return result;
  }

  int? _extractBgmId(Map item) {
    final sites = item['sites'];
    if (sites is! List) return null;
    for (final dynamic site in sites) {
      if (site is! Map) continue;
      if ((site['site'] ?? '').toString() != 'bangumi') continue;
      return int.tryParse((site['id'] ?? '').toString());
    }
    return null;
  }

  List<String> _extractTranslatedTitles(Map item) {
    final result = <String>[];
    final dynamic translations = item['titleTranslate'];
    if (translations is Map) {
      for (final dynamic value in translations.values) {
        if (value is List) {
          for (final dynamic entry in value) {
            final String text = entry.toString().trim();
            if (text.isNotEmpty) result.add(text);
          }
        } else if (value is String && value.trim().isNotEmpty) {
          result.add(value.trim());
        }
      }
    }
    return result;
  }

  /// 本地检索：标题 / 译名 包含关键词，按「完全匹配 > 前缀 > 包含」+ 年份倒序排序。
  Future<List<BangumiItem>> search(
    String keyword, {
    int limit = 20,
    int offset = 0,
  }) async {
    final String query = keyword.trim().toLowerCase();
    if (query.isEmpty) return <BangumiItem>[];
    final subjects = await _ensureLoaded();
    if (subjects.isEmpty) return <BangumiItem>[];

    final matched = <(_LocalSubject, int)>[];
    for (final subject in subjects) {
      final int rank = subject.matchRank(query);
      if (rank >= 0) matched.add((subject, rank));
    }
    matched.sort((a, b) {
      final int byRank = a.$2.compareTo(b.$2);
      if (byRank != 0) return byRank;
      return b.$1.begin.compareTo(a.$1.begin);
    });
    final sliced = matched.skip(offset).take(limit).toList();
    return sliced.map((entry) => entry.$1.toBangumiItem()).toList();
  }
}

class _LocalSubject {
  const _LocalSubject({
    required this.id,
    required this.title,
    required this.translatedTitles,
    required this.begin,
  });

  final int id;
  final String title;
  final List<String> translatedTitles;
  final String begin;

  String get _chineseTitle {
    final zh = translatedTitles;
    if (zh.isEmpty) return '';
    // titleTranslate 里通常含 zh-Hans / zh-Hant 等，取第一条足够展示。
    return zh.first;
  }

  int matchRank(String query) {
    final names = <String>[title, ...translatedTitles];
    int best = -1;
    for (final name in names) {
      final lower = name.toLowerCase();
      if (lower == query) return 0;
      if (lower.startsWith(query)) {
        if (best < 0 || best > 1) best = 1;
      } else if (lower.contains(query)) {
        if (best < 0) best = 2;
      }
    }
    return best;
  }

  BangumiItem toBangumiItem() {
    // 直接构造，避免依赖完整 API JSON 字段。
    return BangumiItem(
      id: id,
      type: 2,
      name: title,
      nameCn: _chineseTitle,
      summary: '',
      airDate: begin,
      airWeekday: 0,
      rank: 0,
      images: <String, String>{
        'large': 'https://api.bgm.tv/v0/subjects/$id/image?type=large',
        'common': 'https://api.bgm.tv/v0/subjects/$id/image?type=large',
        'medium': 'https://api.bgm.tv/v0/subjects/$id/image?type=medium',
        'grid': 'https://api.bgm.tv/v0/subjects/$id/image?type=grid',
        'small': 'https://api.bgm.tv/v0/subjects/$id/image?type=small',
      },
      tags: const <BangumiTag>[],
      alias: const <String>[],
      ratingScore: 0,
      votes: 0,
      votesCount: const <int>[],
      info: '',
    );
  }
}
