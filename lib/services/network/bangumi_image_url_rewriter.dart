abstract final class BangumiImageUrlRewriter {
  static const _apiImageKinds = {'subjects', 'characters', 'persons'};

  static Uri rewrite(Uri uri) {
    if (!isBangumiImage(uri)) return uri;

    final sourceUrl =
        uri.host + uri.path + (uri.hasQuery ? '?${uri.query}' : '');
    final bool animated = uri.path.toLowerCase().endsWith('.gif');
    final int width = _targetWidth(uri);
    return Uri.https('wsrv.nl', '/', {
      'url': sourceUrl,
      // 动图交给 wsrv 原样透传，其余转成 webp 并按用途限宽，下载量更小。
      if (animated) 'n': '-1',
      if (!animated) 'output': 'webp',
      if (!animated) 'w': '$width',
    });
  }

  /// 按图片用途选择请求宽度，避免拉取原图造成慢加载。
  static int _targetWidth(Uri uri) {
    if (uri.host == 'api.bgm.tv') {
      final segments = uri.pathSegments;
      if (segments.length == 4 && segments[3] == 'image') {
        final String kind = segments[1];
        final String type = uri.queryParameters['type'] ?? 'large';
        if (kind == 'subjects') {
          return type == 'small' ? 140 : 480;
        }
        if (kind == 'characters' || kind == 'persons') {
          return type == 'small' ? 96 : 280;
        }
      }
    }
    return 480;
  }

  static bool _isHttp(Uri uri) => uri.scheme == 'http' || uri.scheme == 'https';

  static bool isBangumiImage(Uri uri) =>
      _isHttp(uri) && (uri.host == 'lain.bgm.tv' || _isApiImage(uri));

  static bool _isApiImage(Uri uri) {
    if (uri.host != 'api.bgm.tv') return false;

    final segments = uri.pathSegments;
    if (segments.length != 4 || segments[0] != 'v0' || segments[3] != 'image') {
      return false;
    }
    final id = int.tryParse(segments[2]);
    return _apiImageKinds.contains(segments[1]) && id != null && id > 0;
  }
}
