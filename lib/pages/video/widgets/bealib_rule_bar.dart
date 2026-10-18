import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:bealib/bean/dialog/dialog_helper.dart';
import 'package:bealib/modules/search/plugin_search_module.dart';
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

  Future<void> _showSourcePicker(RuleProbe probe) async {
    if (_switching) return;
    final SearchItem? item = await showModalBottomSheet<SearchItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final ColorScheme scheme = Theme.of(context).colorScheme;
        final TextTheme text = Theme.of(context).textTheme;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('选择片源', style: text.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        '规则「${probe.plugin.name}」找到 ${probe.items.length} 条结果，选择正确的那一部',
                        style: text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: probe.items.length,
                    itemBuilder: (context, index) {
                      final SearchItem candidate = probe.items[index];
                      final bool selected =
                          candidate.src == probe.item?.src;
                      return ListTile(
                        title: Text(
                          candidate.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: selected
                            ? Icon(Icons.check_rounded, color: scheme.primary)
                            : null,
                        onTap: () => Navigator.of(context).pop(candidate),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
    if (item != null && mounted) {
      await _switchToSource(probe, item);
    }
  }

  Future<void> _switchToSource(RuleProbe probe, SearchItem item) async {
    if (_switching) return;
    setState(() => _switching = true);
    try {
      final roads = await probe.plugin.queryChapterRoads(item.src);
      if (!mounted) return;
      if (roads.isEmpty) {
        BealibDialog.showToast(message: '该片源未取到播放列表，请换一条试试');
        return;
      }
      final int currentEpisode =
          widget.videoPageController.selectedEpisode.episode;
      final int initialEpisode =
          currentEpisode > roads.first.data.length ? 1 : currentEpisode;
      context.popAndPushNamed(
        '/video/',
        arguments: OnlineVideoPlaybackArgs(
          bangumiItem: widget.videoPageController.bangumiItem,
          plugin: probe.plugin,
          title: decodeHtmlEntities(item.name),
          src: item.src,
          roads: roads,
          initialRoad: 0,
          initialEpisode: initialEpisode,
        ),
      );
    } catch (error) {
      BealibLogger().w('BealibRuleBar: switch source failed', error: error);
      BealibDialog.showToast(message: '切换片源失败，请稍后重试');
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
          if (selected != null && selected.items.length > 1)
            IconButton(
              tooltip: '选择片源',
              icon: const Icon(Icons.list_alt_rounded, size: 20),
              onPressed: _switching ? null : () => _showSourcePicker(selected),
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
