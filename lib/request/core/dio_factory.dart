import 'package:dio/dio.dart';
import 'package:bealib/request/config/api_endpoints.dart';
import 'package:bealib/request/core/bangumi_transport.dart';
import 'package:bealib/request/core/dio_logger_interceptor.dart';
import 'package:bealib/request/core/network_config.dart';
import 'package:bealib/services/logging/logger.dart';
import 'package:bealib/services/storage/storage.dart';
import 'package:bealib/utils/http_headers.dart';

class DioFactory {
  DioFactory._();

  static Dio? _apiDio;
  static Dio? _bangumiDio;
  static Dio? _rulesRepoDio;
  static Dio? _pluginDio;
  static Dio? _downloadDio;

  static Dio get apiDio => _apiDio ??= _create(
    NetworkConfig.fromSettings(),
    defaultHeaders: {'referer': '', 'user-agent': getRandomUA()},
  );

  static Dio get bangumiDio {
    if (_bangumiDio != null) return _bangumiDio!;
    final config = NetworkConfig.fromSettings();
    final dio = _create(
      config,
      defaultHeaders: {'referer': ''},
      interceptors: [BangumiAccelerationInterceptor()],
    );
    // 镜像节点连接抖动较大，连接超时放宽到 20s（读取超时在客户端逐请求设置）。
    dio.options.connectTimeout = const Duration(seconds: 20);
    dio.httpClientAdapter = BangumiEchAdapter(
      fallback: dio.httpClientAdapter,
      config: config,
    );
    return _bangumiDio = dio;
  }

  static Dio get rulesRepoDio => _rulesRepoDio ??= _create(
    NetworkConfig.fromSettings(),
    defaultHeaders: {'user-agent': getRandomUA()},
    interceptors: [_RulesMirrorInterceptor()],
  );

  static Dio get pluginDio => _pluginDio ??= _create(
    NetworkConfig.fromSettings(),
    defaultHeaders: {
      'user-agent': getRandomUA(),
      'accept-language': getRandomAcceptedLanguage(),
    },
  );

  static Dio get downloadDio => _downloadDio ??= _create(
    NetworkConfig.fromSettings(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
    defaultHeaders: {'user-agent': getRandomUA()},
  );

  static Dio createForConfig(NetworkConfig config) {
    return _create(config);
  }

  static void reset() {
    // Retire old adapters without interrupting requests already in flight.
    _apiDio?.close();
    _bangumiDio?.close();
    _rulesRepoDio?.close();
    _pluginDio?.close();
    _downloadDio?.close();
    _apiDio = null;
    _bangumiDio = null;
    _rulesRepoDio = null;
    _pluginDio = null;
    _downloadDio = null;
  }

  static Dio _create(
    NetworkConfig config, {
    Map<String, dynamic> defaultHeaders = const {},
    List<Interceptor> interceptors = const [],
  }) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.receiveTimeout,
        sendTimeout: config.sendTimeout,
        headers: defaultHeaders,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    dio.httpClientAdapter = config.createAdapter();
    dio.interceptors.addAll(interceptors);
    if (config.enableLog) {
      dio.interceptors.add(DioLoggerInterceptor());
    }
    return dio;
  }
}

class _RulesMirrorInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final enableGitProxy = GStorage.getSetting(SettingsKeys.enableGitProxy);
    if (!enableGitProxy) {
      handler.next(options);
      return;
    }

    final url = options.uri.toString();
    if (!url.startsWith(ApiEndpoints.pluginShop)) {
      handler.next(options);
      return;
    }

    final mirrored =
        ApiEndpoints.pluginShopMirror +
        url.substring(ApiEndpoints.pluginShop.length);
    BealibLogger().d('Rules mirror: $mirrored');
    options.path = mirrored;
    handler.next(options);
  }
}
