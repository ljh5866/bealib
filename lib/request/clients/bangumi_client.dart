import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:bealib/request/config/api_endpoints.dart';
import 'package:bealib/request/core/bangumi_response_cache.dart';
import 'package:bealib/request/core/bangumi_transport.dart';
import 'package:bealib/request/core/dio_factory.dart';
import 'package:bealib/request/core/network_error_mapper.dart';
import 'package:bealib/services/network/bangumi_acceleration.dart';
import 'package:bealib/services/storage/storage.dart';
import 'package:bealib/utils/bangumi_mirror_credentials.dart';
import 'package:bealib/utils/constants.dart';
import 'package:bealib/utils/crypto.dart';

class BangumiClient {
  BangumiClient._();

  static final BangumiClient instance = BangumiClient._();

  Future<dynamic> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = false,
    String? accessToken,
    CancelToken? cancelToken,
    Duration? receiveTimeout,
  }) async {
    final bool cacheable = !requiresAuth &&
        (accessToken == null || accessToken.isEmpty) &&
        cancelToken == null;
    final String cacheKey = _cacheKey(url, queryParameters);
    if (cacheable) {
      final cached = await BangumiResponseCache.instance.read(cacheKey);
      if (cached != null) return cached;
    }
    try {
      final response = await DioFactory.bangumiDio.get(
        url,
        queryParameters: queryParameters,
        options: Options(
          // 镜像延迟抖动大（实测 1–45s），12s 太容易超时。
          receiveTimeout: receiveTimeout ?? const Duration(seconds: 25),
          headers: _headers(
            requiresAuth: requiresAuth,
            accessToken: accessToken,
            url: url,
            method: 'GET',
          ),
        ),
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (cacheable) {
        unawaited(BangumiResponseCache.instance.write(cacheKey, data));
      }
      return data;
    } on DioException catch (e) {
      if (BangumiAcceleration.current == BangumiAcceleration.ech) {
        try {
          final retried = await DioFactory.bangumiDio.get(
            url,
            queryParameters: queryParameters,
            options: Options(
              receiveTimeout:
                  receiveTimeout ?? const Duration(seconds: 25),
              headers: _headers(
                requiresAuth: requiresAuth,
                accessToken: accessToken,
                url: url,
                method: 'GET',
              ),
              extra: const <String, dynamic>{forceMirrorKey: true},
            ),
            cancelToken: cancelToken,
          );
          final data = retried.data;
          if (cacheable) {
            unawaited(BangumiResponseCache.instance.write(cacheKey, data));
          }
          return data;
        } catch (_) {
          // 镜像兜底也失败时继续走下面的旧缓存/抛错逻辑。
        }
      }
      if (cacheable) {
        final stale = await BangumiResponseCache.instance.readStale(cacheKey);
        if (stale != null) return stale;
      }
      throw await NetworkErrorMapper.mapException(e);
    }
  }

  String _cacheKey(String url, Map<String, dynamic>? queryParameters) {
    if (queryParameters == null || queryParameters.isEmpty) return url;
    final uri = Uri.parse(url);
    return uri.replace(queryParameters: queryParameters).toString();
  }

  Future<dynamic> post(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = false,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await DioFactory.bangumiDio.post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          headers: _headers(
            requiresAuth: requiresAuth,
            url: url,
            method: 'POST',
            data: data,
          ),
        ),
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (e) {
      throw await NetworkErrorMapper.mapException(e);
    }
  }

  Map<String, dynamic> _headers({
    required bool requiresAuth,
    String? accessToken,
    required String url,
    required String method,
    Object? data,
  }) {
    final headers = <String, dynamic>{...bangumiHTTPHeader};
    final bangumiSyncEnable = GStorage.getSetting(
      SettingsKeys.bangumiSyncEnable,
    );
    final token =
        (accessToken ??
                GStorage.getSetting<String>(SettingsKeys.bangumiAccessToken))
            .trim();
    if ((requiresAuth || bangumiSyncEnable) && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (_shouldSignProtectedMirrorRequest(url, method)) {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final body = data == null ? '' : jsonEncode(data);
      headers['X-AppId'] = bangumiMirrorCredentials['id'];
      headers['X-Timestamp'] = timestamp;
      headers['X-Signature'] = generateBangumiMirrorSearchSignature(
        method: method,
        path: Uri.parse(url).path,
        body: body,
        timestamp: timestamp,
      );
    }
    return headers;
  }

  bool _shouldSignProtectedMirrorRequest(String url, String method) {
    final uri = Uri.parse(url);
    if (BangumiAcceleration.current != BangumiAcceleration.mirror ||
        !ApiEndpoints.bangumiPublicApiHosts.contains(uri.host)) {
      return false;
    }
    final path = uri.path;
    if (method == 'POST' && path == '/v0/search/subjects') {
      return true;
    }
    if (method != 'GET') {
      return false;
    }
    return path.startsWith('/p1/subjects/') && path.endsWith('/comments') ||
        path.startsWith('/p1/episodes/') && path.endsWith('/comments') ||
        path.startsWith('/p1/characters/') && path.endsWith('/comments');
  }
}
