import 'package:flutter/services.dart' show appBuildName;

class ApiEndpoints {
  /// 当前版本
  static const String version = appBuildName ?? '0.0.0';

  /// 规则API级别
  static const int apiLevel = 9;

  /// 项目主页
  static const String projectUrl = "https://kazumi.app/";

  /// Github 项目主页
  static const String sourceUrl = "https://github.com/ljh5866/bealib";

  /// 图标作者
  static const String iconUrl = "https://www.pixiv.net/users/66219277";

  /// 规则仓库
  static const String pluginShop =
      'https://raw.githubusercontent.com/Predidit/KazumiRules/main/';

  /// 规则仓库镜像
  static const String pluginShopMirror =
      'https://raw.gitcode.com/gh_mirrors/ka/KazumiRules/raw/main/';

  /// 在线升级：固定走 GitHub Releases。
  ///
  /// 仓库地址默认 [updateRepo]，可在构建时覆盖：
  ///   --dart-define=BEALIB_UPDATE_REPO=owner/repo
  /// 也可用 --dart-define=BEALIB_UPDATE_API=<url> 指向本地/镜像的
  /// GitHub Release JSON（用于测试更新流程）。
  static const String updateRepo = String.fromEnvironment(
    'BEALIB_UPDATE_REPO',
    defaultValue: 'ljh5866/bealib',
  );

  static const String _updateApiOverride =
      String.fromEnvironment('BEALIB_UPDATE_API');

  /// 检查更新接口（GitHub Releases API，或测试用的覆盖地址）。
  static String get updateCheckUrl => _updateApiOverride.isNotEmpty
      ? _updateApiOverride
      : 'https://api.github.com/repos/$updateRepo/releases/latest';

  /// GitHub Release 资产下载代理（按顺序尝试）。
  ///
  /// 部分网络能访问 GitHub API，但下载 release 资产会超时/被重置；
  /// 此时自动用这些代理前缀重试（代理地址后可拼接完整 GitHub URL）。
  static const List<String> updateDownloadProxies = [
    'https://ghfast.top/',
    'https://ghproxy.net/',
    'https://gh-proxy.com/',
  ];

  /// 版本策略文件（仓库根目录 update-policy.json，可在 GitHub 上直接编辑）。
  static const String updatePolicyApi =
      'https://api.github.com/repos/$updateRepo/contents/update-policy.json?ref=main';
  static const String updatePolicyCdn =
      'https://cdn.jsdelivr.net/gh/$updateRepo@main/update-policy.json';
  static const String updatePolicyRaw =
      'https://raw.githubusercontent.com/$updateRepo/main/update-policy.json';

  /// 按顺序尝试的策略地址（Contents API 最新 → jsDelivr → raw）。
  static const List<String> updatePolicyUrls = [
    updatePolicyApi,
    updatePolicyCdn,
    updatePolicyRaw,
  ];

  /// 官方网站。
  static const String officialWebsite = 'https://www.ttals.com/';

  /// 发布页（无法应用内下载时打开）。
  static const String latestApp =
      'https://github.com/$updateRepo/releases/latest';

  /// Bangumi 镜像测试后端
  static const String bangumiMirrorDomain = 'https://api.kazumi.fyi';

  /// 弹弹官网
  static const String dandanIndex = 'https://www.dandanplay.com/';

  /// Bangumi 官网
  static const String bangumiIndex = 'https://bangumi.tv/';

  /// bangumi API
  static const String bangumiAPIDomain = 'https://api.bgm.tv';

  /// Bangumi 鉴权 API
  static const String bangumiAuthAPIMirrorDomain = 'https://api.bgmapi.com';

  /// Telegram 群组
  static const String telegramGroup = 'https://t.me/bealib_app';

  /// 番剧信息
  static const String bangumiInfoByID = '/v0/subjects/{0}';

  /// 条目关联信息
  static const String bangumiRelationsByID = '/v0/subjects/{0}/subjects';

  /// 条目搜索
  static const String bangumiRankSearch =
      '/v0/search/subjects?limit={0}&offset={1}';

  /// 从条目ID获取角色信息
  static const String bangumiCharacterByID = '/v0/subjects/{0}/characters';

  /// 从条目ID获取工作人员信息
  static const String bangumiStaffByID = '/v0/subjects/{0}/persons';

  /// 从条目ID获取剧集ID
  static const String bangumiEpisodeByID = '/v0/episodes';

  /// 返回当前 Access Token 对应的用户信息
  static const String bangumiUsernameByToken = '/v0/me';

  /// 新增或修改用户单个条目收藏
  static const String bangumiSetCollection = '/v0/users/-/collections/{0}';

  /// 获取用户全部收藏（不限类型）。用户名，分页参数1(limit)，分页参数2(offset)
  static const String bangumiGetAllCollections =
      '/v0/users/{0}/collections?subject_type=2&limit={1}&offset={2}';

  /// Bangumi Next API Domain
  static const String bangumiAPINextDomain = 'https://next.bgm.tv';

  static const bangumiPublicApiHosts = {'api.bgm.tv', 'next.bgm.tv'};

  /// 每日放送
  static const String bangumiCalendar = '/p1/calendar';

  /// 番剧趋势
  static const String bangumiTrendsNext = '/p1/trending/subjects';

  /// Bealib Bangumi 镜像缓存榜单
  static const String bangumiMirrorPopularSubjects =
      '/kazumi/v1/popular/subjects';

  /// Bealib Bangumi 镜像季节时间表
  static const String bangumiMirrorSeasonCalendar =
      '/kazumi/v1/calendar/season';

  /// 番剧信息
  static const String bangumiInfoByIDNext = '/p1/subjects/{0}';

  /// 番剧评论
  static const String bangumiCommentsByIDNext =
      '/p1/subjects/{0}/comments?limit={1}&offset={2}';

  /// 番剧剧集评论
  static const String bangumiEpisodeCommentsByIDNext =
      '/p1/episodes/{0}/comments';

  /// 番剧角色信息
  static const String bangumiCharacterInfoByCharacterIDNext =
      '/p1/characters/{0}';

  /// 番剧角色评论
  static const String bangumiCharacterCommentsByIDNext =
      '/p1/characters/{0}/comments';

  /// DanDanPlay API Domain
  static const String dandanAPIDomain = 'https://api.dandanplay.net';

  /// 获取弹幕
  static const String dandanAPIComment = "/api/v2/comment/";

  /// 检索弹弹番剧元数据
  static const String dandanAPISearchEpisodes = "/api/v2/search/episodes";

  /// 获取弹弹番剧元数据
  static const String dandanAPIInfo = "/api/v2/bangumi/";

  /// 获取弹弹番剧元数据（通过BGM番剧ID）
  static const String dandanAPIInfoByBgmBangumiId = "/api/v2/bangumi/bgmtv/{0}";

  /// 图片识别番剧
  static const String traceApi = 'https://api.trace.moe/search';

  static String formatUrl(String url, List<dynamic> params) {
    for (int i = 0; i < params.length; i++) {
      url = url.replaceAll('{$i}', params[i].toString());
    }
    return url;
  }
}
