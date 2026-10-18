import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:bealib/modules/bangumi/bangumi_item.dart';
import 'package:bealib/pages/video/video_playback_args.dart';
import 'package:bealib/utils/theme.dart';

/// `/info/` 入口的过渡页：把「选番剧」直接转成「播放页」。
///
/// 播放页 = 顶部播放器 + 下方「番剧信息 / 选集」两个 Tab；
/// 进入时由播放页自动检索全部规则并选中速度最优的一条开播。
class BealibWatchEntryPage extends StatefulWidget {
  const BealibWatchEntryPage({super.key, required this.bangumiItem});

  final BangumiItem bangumiItem;

  @override
  State<BealibWatchEntryPage> createState() => _BealibWatchEntryPageState();
}

class _BealibWatchEntryPageState extends State<BealibWatchEntryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.popAndPushNamed(
        '/video/',
        arguments: PendingOnlinePlaybackArgs(bangumiItem: widget.bangumiItem),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String title = widget.bangumiItem.nameCn.isNotEmpty
        ? widget.bangumiItem.nameCn
        : widget.bangumiItem.name;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: BealibTokens.ambientBackground(brightness),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_circle_fill_rounded,
                    size: 56, color: scheme.primary),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: text.titleMedium
                      ?.copyWith(color: scheme.onSurface),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(height: 10),
                Text(
                  '正在选择最快播放规则…',
                  style: text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
