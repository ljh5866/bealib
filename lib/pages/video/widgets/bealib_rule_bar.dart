import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:bealib/bean/dialog/dialog_helper.dart';
import 'package:bealib/pages/video/video_controller.dart';
import 'package:bealib/pages/video/video_playback_args.dart';
import 'package:bealib/services/logging/logger.dart';
import 'package:bealib/services/plugin/rule_resolver.dart';
import 'package:bealib/utils/html_text.dart';

/// 播放页「选集」Tab 顶部的规则切换条。
///
/// 规则支持手动切换，播放失败时视频页也会自动切换其它规则；切换后会重新解析该规则的
/// 播放线路，并以新规则重新进入播放页。
class BealibRuleBar extends StatefulWidget {
  const BealibRuleBar({super.key, required this.videoPageController});

  final VideoPageController videoPageController;

  @override
  State<BealibRuleBar> createState() => _BealibRuleBarState();
}

class _BealibRuleBarState extends State<BealibRuleBar> {
  bool _switching = false;

  RuleProbe? get _selected {
    final String name = widget.videoPageController.currentPlugin.name;
    for (final probe in RuleResolver.lastProbes) {
      if (probe.plugin.name == name) return probe;
    }
    return null;
  }

  Future<void> _switchRule(RuleProbe probe) async {
    if (_switching || probe.plugin.name == _selected?.plugin.name) return;
    setState(() => _switching = true);
    try {
      if (!probe.hasResult) {
        await RuleResolver.ensureProbe(probe);
      }
      if (!probe.hasResult) {
        BealibDialog.showToast(
          message: probe.noResult ? '该规则没有检索到这部番剧' : '该规则检索失败，请稍后重试',
        );
        return;
      }
      final roads = await RuleResolver.loadRoads(probe);
      if (!mounted) return;
      if (roads.isEmpty) {
        BealibDialog.showToast(message: '该规则未能获取播放列表');
        return;
      }
      final currentEpisode = widget.videoPageController.selectedEpisode.episode;
      final int initialEpisode =
          currentEpisode > roads.first.data.length ? 1 : currentEpisode;
      context.popAndPushNamed(
        '/video/',
        arguments: OnlineVideoPlaybackArgs(
          bangumiItem: widget.videoPageController.bangumiItem,
          plugin: probe.plugin,
          title: decodeHtmlEntities(probe.item!.name),
          src: probe.item!.src,
          roads: roads,
          initialRoad: 0,
          initialEpisode: initialEpisode,
        ),
      );
    } catch (error) {
      BealibLogger().w('BealibRuleBar: switch rule failed', error: error);
      BealibDialog.showToast(message: '切换规则失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (RuleResolver.lastProbes.isEmpty) return const SizedBox.shrink();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final RuleProbe? selected = _selected;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      color: scheme.surface,
      child: Row(
        children: [
          Text(
            '播放规则',
            style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<RuleProbe>(
                isExpanded: true,
                value: selected,
                hint: const Text('选择播放规则'),
                items: [
                  for (final probe in RuleResolver.lastProbes)
                    DropdownMenuItem<RuleProbe>(
                      value: probe,
                      child: Text(
                        _label(probe),
                        overflow: TextOverflow.ellipsis,
                        style: text.labelLarge,
                      ),
                    ),
                ],
                onChanged: _switching
                    ? null
                    : (probe) {
                        if (probe != null) _switchRule(probe);
                      },
              ),
            ),
          ),
          if (_switching)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  String _label(RuleProbe probe) {
    if (probe.hasResult) {
      return '${probe.plugin.name} · ${probe.elapsedMs}ms';
    }
    if (probe.noResult) return '${probe.plugin.name} · 无结果';
    return '${probe.plugin.name} · ${probe.error ?? '检索失败'}';
  }
}
