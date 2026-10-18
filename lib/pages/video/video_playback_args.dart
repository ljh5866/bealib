import 'package:bealib/modules/bangumi/bangumi_item.dart';
import 'package:bealib/modules/download/download_module.dart';
import 'package:bealib/modules/roads/road_module.dart';
import 'package:bealib/plugins/plugins.dart';

/// Route arguments for '/video/'. Entry points hand playback context over
/// through the route instead of pre-filling a shared controller, which lets
/// [VideoPageController] live and die with the route.
sealed class VideoPlaybackArgs {
  const VideoPlaybackArgs({required this.bangumiItem});

  final BangumiItem bangumiItem;
}

class OnlineVideoPlaybackArgs extends VideoPlaybackArgs {
  const OnlineVideoPlaybackArgs({
    required super.bangumiItem,
    required this.plugin,
    required this.title,
    required this.src,
    required this.roads,
    this.initialRoad,
    this.initialEpisode,
  });

  final Plugin plugin;
  final String title;
  final String src;
  final List<Road> roads;

  /// 详情页选集中的起始线路/集数（为空则按历史续播或第 1 集）。
  final int? initialRoad;
  final int? initialEpisode;
}

/// 只有番剧信息、规则/线路尚未解析的入口参数。
/// 播放页会并发检索全部规则，选中速度最优的一条后自动开播。
class PendingOnlinePlaybackArgs extends VideoPlaybackArgs {
  const PendingOnlinePlaybackArgs({required super.bangumiItem});
}

class OfflineVideoPlaybackArgs extends VideoPlaybackArgs {
  const OfflineVideoPlaybackArgs({
    required super.bangumiItem,
    required this.pluginName,
    required this.episodeNumber,
    required this.road,
    required this.downloadedEpisodes,
  });

  final String pluginName;
  final int episodeNumber;
  final int road;
  final List<DownloadEpisode> downloadedEpisodes;
}
