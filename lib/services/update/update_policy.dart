import 'dart:convert';

import 'package:bealib/request/clients/download_http_client.dart';
import 'package:bealib/request/config/api_endpoints.dart';
import 'package:bealib/services/logging/logger.dart';
import 'package:bealib/utils/version.dart';

/// 远端版本策略（仓库根目录 `update-policy.json`，可随时在 GitHub 网页上改）。
///
/// 用途：
/// - `minSupportedVersion`：低于该版本的客户端强制更新；
/// - `blockedVersions`：被停用的具体版本（强制更新）；
/// - `message`：强制更新/停用时展示给用户的说明。
class UpdatePolicy {
  const UpdatePolicy({
    this.minSupportedVersion = '',
    this.blockedVersions = const [],
    this.message = '',
  });

  final String minSupportedVersion;
  final List<String> blockedVersions;
  final String message;

  factory UpdatePolicy.fromJson(Map<String, dynamic> json) {
    final blocked = json['blockedVersions'];
    return UpdatePolicy(
      minSupportedVersion:
          (json['minSupportedVersion'] as String?)?.trim() ?? '',
      blockedVersions: blocked is List
          ? blocked
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false)
          : const [],
      message: (json['message'] as String?)?.trim() ?? '',
    );
  }

  bool blocks(String currentVersion) {
    final current = currentVersion.trim();
    if (current.isEmpty) return false;
    if (minSupportedVersion.isNotEmpty &&
        needUpdate(current, minSupportedVersion)) {
      return true;
    }
    return blockedVersions.any((version) => version == current);
  }

  String reasonFor(String currentVersion) {
    final current = currentVersion.trim();
    if (message.isNotEmpty) return message;
    if (blockedVersions.contains(current)) {
      return '当前版本 $current 已停用，请更新到最新版本后继续使用。';
    }
    return '当前版本 $current 已不再支持，请更新到最新版本后继续使用。';
  }
}

/// 拉取并缓存版本策略（10 分钟内复用，避免每次检查更新都请求）。
class UpdatePolicyService {
  UpdatePolicyService._();

  static final UpdatePolicyService instance = UpdatePolicyService._();
  static const Duration _ttl = Duration(minutes: 10);

  UpdatePolicy? _cached;
  DateTime? _fetchedAt;

  Future<UpdatePolicy?> fetch({bool forceRefresh = false}) async {
    final now = DateTime.now();
    final fetchedAt = _fetchedAt;
    if (!forceRefresh &&
        _cached != null &&
        fetchedAt != null &&
        now.difference(fetchedAt) < _ttl) {
      return _cached;
    }
    for (final url in ApiEndpoints.updatePolicyUrls) {
      try {
        final raw = await DownloadHttpClient.instance.getPlain(
          url,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'Bealib-Android',
          },
          receiveTimeout: const Duration(seconds: 12),
        );
        final policy = _parse(raw);
        if (policy != null) {
          _cached = policy;
          _fetchedAt = now;
          return policy;
        }
      } catch (error) {
        BealibLogger().w('Update: policy fetch failed ($url)', error: error);
      }
    }
    return _cached;
  }

  void clearCache() {
    _cached = null;
    _fetchedAt = null;
  }

  UpdatePolicy? _parse(String raw) {
    if (raw.trim().isEmpty) return null;
    Object? decoded;
    try {
      decoded = json.decode(raw);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final map = Map<String, dynamic>.from(decoded);
    // GitHub Contents API 返回 {content: base64, encoding: base64}
    final content = map['content'];
    if (content is String && content.trim().isNotEmpty) {
      try {
        final bytes = base64.decode(content.replaceAll(RegExp(r'\s'), ''));
        final inner = json.decode(utf8.decode(bytes));
        if (inner is Map) {
          return UpdatePolicy.fromJson(Map<String, dynamic>.from(inner));
        }
        return null;
      } catch (_) {
        return null;
      }
    }
    return UpdatePolicy.fromJson(map);
  }
}
