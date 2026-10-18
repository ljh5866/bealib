import 'package:cached_network_image/cached_network_image.dart';
import 'package:bealib/request/core/dio_factory.dart';
import 'package:bealib/services/logging/logger.dart';
import 'package:bealib/services/network/proxy_aware_image_cache_manager.dart';

// WebView proxies are configured separately by their platform controllers.
class ProxyManager {
  ProxyManager._();

  static void applyProxy() {
    DioFactory.reset();
    _applyImageCacheManager();
    BealibLogger().i('Proxy: 网络客户端配置已刷新');
  }

  static void clearProxy() {
    DioFactory.reset();
    _applyImageCacheManager();
    BealibLogger().i('Proxy: 网络客户端代理已清除');
  }

  static void _applyImageCacheManager() {
    ProxyAwareImageCacheManager.instance.resetNetworkClients();
    CachedNetworkImageProvider.defaultCacheManager =
        ProxyAwareImageCacheManager.instance;
  }
}
