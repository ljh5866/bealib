import 'dart:async';

import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:window_manager/window_manager.dart';

import 'package:bealib/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:bealib/bean/dialog/dialog_helper.dart';
import 'package:bealib/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:bealib/bean/widget/embedded_native_control_area.dart';
import 'package:bealib/bean/widget/loading_indicator.dart';
import 'package:bealib/bean/widget/media_error_widget.dart';
import 'package:bealib/modules/download/download_module.dart';
import 'package:bealib/pages/download/download_controller.dart';
import 'package:bealib/pages/download/download_episode_sheet.dart';
import 'package:bealib/pages/history/history_controller.dart';
import 'package:bealib/pages/player/player_controller.dart';
import 'package:bealib/pages/player/player_item.dart';
import 'package:bealib/pages/video/episode_selection_panel.dart';
import 'package:bealib/pages/video/player_content_tabs.dart';
import 'package:bealib/pages/video/widgets/bealib_rule_bar.dart';
import 'package:bealib/pages/video/widgets/bealib_video_info_panel.dart';
import 'package:bealib/plugins/plugins_controller.dart';
import 'package:bealib/request/apis/bangumi_api.dart';
import 'package:bealib/modules/roads/road_module.dart';
import 'package:bealib/pages/player/controller/player_playback_controller.dart';
import 'package:bealib/services/logging/logger.dart';
import 'package:bealib/services/plugin/rule_resolver.dart';
import 'package:bealib/utils/html_text.dart';
import 'package:bealib/pages/video/video_controller.dart';
import 'package:bealib/pages/video/video_playback_args.dart';
import 'package:bealib/pages/video/video_page_layout.dart';
import 'package:bealib/pages/video/video_side_panel.dart';
import 'package:bealib/pages/video/video_system_bars.dart';
import 'package:bealib/services/player/pip_utils.dart';
import 'package:bealib/services/player/timed_shutdown_service.dart';
import 'package:bealib/services/storage/storage.dart';
import 'package:bealib/utils/device.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({
    super.key,
    required this.args,
    required this.playerController,
    required this.videoPageController,
    required this.historyController,
    required this.downloadController,
  });

  final VideoPlaybackArgs args;
  final PlayerController playerController;
  final VideoPageController videoPageController;
  final HistoryController historyController;
  final DownloadController downloadController;

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage>
    with SingleTickerProviderStateMixin, WindowListener {
  PlayerController get playerController => widget.playerController;
  VideoPageController get videoPageController => widget.videoPageController;
  bool _didInitializePlayback = false;
  bool _isExiting = false;
  HistoryController get historyController => widget.historyController;
  DownloadController get downloadController => widget.downloadController;
  late bool playResume;
  bool showDebugLog = false;
  List<String> webviewLogLines = [];
  StreamSubscription<String>? _logSubscription;
  final FocusNode keyboardFocus =
      FocusNode(debugLabel: 'Video player shortcut scope');

  final _episodePanelKey = GlobalKey<EpisodeSelectionPanelState>();
  final _sidePanelKey = GlobalKey<VideoSidePanelState>();
  late TabController tabController;

  String? _pendingResolutionError;

  // 播放失败自动切换规则：同一番剧内记录已尝试过的规则，避免来回循环。
  static final Set<String> _autoSwitchedPlugins = <String>{};
  static int? _autoSwitchBangumiId;
  bool _autoSwitchingRule = false;
  String? _handledPlaybackError;

  late final bool disableAnimations;

  StreamSubscription<SyncPlayChatMessage>? _syncChatSubscription;
  late final mobx.ReactionDisposer _pipModeListener;
  LocalHistoryEntry? _desktopPipEntry;

  static const Duration _offlinePlayerInitDelay = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    videoPageController.applyPlaybackArgs(widget.args);
    final int bangumiId = videoPageController.bangumiItem.id;
    if (_autoSwitchBangumiId != bangumiId) {
      _autoSwitchBangumiId = bangumiId;
      _autoSwitchedPlugins.clear();
    }
    setActionablePlayerErrorHandler(this, _handlePlayerStreamError);
    windowManager.addListener(this);

    tabController = TabController(length: 2, vsync: this);

    playResume = GStorage.getSetting(SettingsKeys.playResume);
    disableAnimations =
        GStorage.getSetting(SettingsKeys.playerDisableAnimations);
    _pipModeListener = mobx.reaction<bool>(
      (_) => videoPageController.isPip,
      _syncDesktopPipHistory,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitializePlayback) {
      return;
    }
    _didInitializePlayback = true;
    videoPageController.fullscreen.attach(ModalRoute.of(context)!);
    if (isDesktop()) {
      unawaited(videoPageController.fullscreen
          .initializeDesktop(windowManager.isFullScreen));
    }
    _initializePlayback();
  }

  void _initializePlayback() {
    _syncChatSubscription =
        playerController.syncplay.chatStream.listen((event) {
      final localUsername =
          playerController.syncplay.syncplayController?.username ?? '';
      final String displayText = '${event.username}：${event.message}';

      if (playerController.danmaku.danmakuOn &&
          event.username != localUsername &&
          event.fromRemote) {
        playerController.danmaku.canvasController?.addDanmaku(
          DanmakuContentItem(
            displayText,
            color: Colors.orange,
            isColorful: true,
            type: DanmakuItemType.bottom,
            extra: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
    });

    if (videoPageController.isOfflineMode) {
      _initOfflineMode();
      return;
    }
    if (widget.args is PendingOnlinePlaybackArgs) {
      unawaited(_resolvePendingOnline());
      return;
    }
    _initOnlineMode();
  }

  void _handlePlayerStreamError(String message) {
    if (!mounted) return;
    _scheduleAutoSwitch(message);
  }

  void _scheduleAutoSwitch(String reason) {
    if (_handledPlaybackError == reason) return;
    _handledPlaybackError = reason;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _autoSwitchRule(reason);
    });
  }

  /// 当前规则播放失败时，按检索速度自动尝试其它有结果的规则。
  Future<void> _autoSwitchRule(String reason) async {
    if (_autoSwitchingRule) return;
    final List<RuleProbe> candidates = RuleResolver.lastProbes
        .where((probe) =>
            probe.hasResult &&
            !_autoSwitchedPlugins.contains(probe.plugin.name))
        .toList();
    if (candidates.isEmpty) return;
    _autoSwitchingRule = true;
    try {
      for (final RuleProbe probe in candidates) {
        if (!mounted) return;
        _autoSwitchedPlugins.add(probe.plugin.name);
        try {
          if (!probe.hasResult) {
            await RuleResolver.ensureProbe(probe);
          }
          if (!probe.hasResult || !mounted) continue;
          final List<Road> roads = await RuleResolver.loadRoads(probe);
          if (!mounted || roads.isEmpty) continue;
          final int currentEpisode =
              videoPageController.selectedEpisode.episode;
          final int initialEpisode =
              currentEpisode > roads.first.data.length ? 1 : currentEpisode;
          BealibDialog.showToast(
            message: '「${videoPageController.currentPlugin.name}」播放失败，'
                '正在切换到「${probe.plugin.name}」',
          );
          context.popAndPushNamed(
            '/video/',
            arguments: OnlineVideoPlaybackArgs(
              bangumiItem: videoPageController.bangumiItem,
              plugin: probe.plugin,
              title: decodeHtmlEntities(probe.item!.name),
              src: probe.item!.src,
              roads: roads,
              initialRoad: 0,
              initialEpisode: initialEpisode,
            ),
          );
          return;
        } catch (error) {
          BealibLogger().w(
            'VideoPage: auto switch rule failed (${probe.plugin.name})',
            error: error,
          );
        }
      }
    } finally {
      _autoSwitchingRule = false;
    }
  }

  Future<void> _resolvePendingOnline() async {
    setState(() => _pendingResolutionError = null);
    // 本地搜索的结果可能只有基础字段（英文标题、无别名），先按 ID 拉取详情，
    // 拿到中文名/封面/简介后再用中文标题去规则里检索，避免“搜到却播不了”。
    final item = videoPageController.bangumiItem;
    if (item.id > 0 && item.nameCn.trim().isEmpty) {
      try {
        final detail = await BangumiApi.getBangumiInfoByID(item.id);
        if (detail != null && detail.nameCn.trim().isNotEmpty) {
          videoPageController.bangumiItem = detail;
        }
      } catch (_) {
        // 拉取失败时继续用现有标题尝试。
      }
      if (!mounted) return;
    }
    final String keyword = RuleResolver.resolveKeyword(
      videoPageController.bangumiItem.nameCn,
      videoPageController.bangumiItem.name,
    );
    try {
      final plugins = inject<PluginsController>().pluginList.toList();
      if (plugins.isEmpty) {
        if (!mounted) return;
        setState(() {
          _pendingResolutionError = '还没有规则，请先到「设置 → 规则设置」添加规则';
        });
        return;
      }
      final fastest = await RuleResolver.probeAll(plugins, keyword);
      if (!mounted) return;
      if (fastest == null) {
        setState(() {
          _pendingResolutionError = '没有规则检索到这部番剧，可在「选集」里手动切换规则重试';
        });
        return;
      }
      // 按检索速度依次尝试有结果的规则：最快规则拿不到播放列表时自动切换到下一条。
      RuleProbe? chosen;
      List<Road> roads = const <Road>[];
      for (final RuleProbe probe in RuleResolver.lastProbes) {
        if (!probe.hasResult) continue;
        try {
          final List<Road> candidateRoads =
              await RuleResolver.loadRoads(probe);
          if (!mounted) return;
          if (candidateRoads.isNotEmpty) {
            chosen = probe;
            roads = candidateRoads;
            break;
          }
        } catch (error) {
          BealibLogger().w(
            'VideoPage: rule ${probe.plugin.name} failed to load roads',
            error: error,
          );
        }
      }
      if (chosen == null || roads.isEmpty) {
        setState(() {
          _pendingResolutionError = '规则均未能获取播放列表，可在「选集」里手动切换规则重试';
        });
        return;
      }
      if (chosen.plugin.name != fastest.plugin.name) {
        BealibDialog.showToast(
          message: '最快规则未能获取播放列表，已自动切换到「${chosen.plugin.name}」',
        );
      }
      videoPageController.applyResolvedOnlineSource(
        plugin: chosen.plugin,
        title: decodeHtmlEntities(chosen.item!.name),
        src: chosen.item!.src,
        roads: roads,
      );
      _initOnlineMode();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pendingResolutionError = '解析播放规则失败，请稍后重试';
      });
    }
  }

  /// 播放器区域占位：页面已打开，仅播放器在等规则检索。
  Widget _buildPlayerResolutionPlaceholder() {
    final theme = Theme.of(context);
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: _pendingResolutionError == null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '正在选择最快播放规则…',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  '番剧信息已加载，可先查看下方内容',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: Colors.white38),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _pendingResolutionError!,
                  textAlign: TextAlign.center,
                  style:
                      theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _resolvePendingOnline,
                  child: const Text('重试'),
                ),
              ],
            ),
    );
  }

  /// 选集 Tab 占位：规则检索完成后自动替换成规则条 + 剧集列表。
  Widget _buildEpisodesResolutionPlaceholder() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pendingResolutionError == null) ...[
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: 12),
              Text(
                '正在检索规则并准备剧集…',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ] else ...[
              Text(
                _pendingResolutionError!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _resolvePendingOnline,
                child: const Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _initOfflineMode() {
    final identity = videoPageController.currentHistoryIdentity;
    videoPageController.historyOffset = identity == null
        ? 0
        : videoPageController.getHistoryOffsetFor(identity);
    _revealCurrentEpisode();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(_offlinePlayerInitDelay);
      if (!mounted) {
        return;
      }

      await changeEpisode(
        videoPageController.selectedEpisode.episode,
        currentRoad: videoPageController.selectedEpisode.road,
        offset: videoPageController.historyOffset,
      );
    });
  }

  void _initOnlineMode() {
    videoPageController.historyOffset = 0;

    final explicit = videoPageController.explicitInitialSelection;
    if (explicit != null) {
      // 详情页选集明确指定了线路/集数：直接播放该集，不被历史续播覆盖。
      videoPageController.resetEpisodeState(
        episode: explicit.episode,
        road: explicit.road,
      );
      final identity = videoPageController.currentHistoryIdentity;
      videoPageController.historyOffset = identity == null
          ? 0
          : videoPageController.getHistoryOffsetFor(identity);
    } else {
      var progress = historyController.lastWatching(
          videoPageController.bangumiItem,
          videoPageController.currentPlugin.name);
      if (progress != null) {
        if (videoPageController.roadList.length > progress.road) {
          if (videoPageController.roadList[progress.road].data.length >=
              progress.episode) {
            videoPageController.resetEpisodeState(
              episode: progress.episode,
              road: progress.road,
            );
            if (playResume) {
              videoPageController.historyOffset = progress.progress.inSeconds;
            }
          }
        }
      }
    }
    _revealCurrentEpisode();

    _logSubscription = videoPageController.logStream.listen((log) {
      if (mounted) {
        setState(() {
          webviewLogLines.add(log);
          if (webviewLogLines.length > 100) {
            webviewLogLines.removeAt(0);
          }
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      changeEpisode(videoPageController.selectedEpisode.episode,
          currentRoad: videoPageController.selectedEpisode.road,
          offset: videoPageController.historyOffset);
    });
  }

  @override
  void dispose() {
    try {
      windowManager.removeListener(this);
    } catch (_) {}
    try {
      _syncChatSubscription?.cancel();
    } catch (_) {}
    try {
      setActionablePlayerErrorHandler(this, null);
      _logSubscription?.cancel();
    } catch (_) {}
    _pipModeListener();
    _desktopPipEntry?.remove();
    _desktopPipEntry = null;
    if (!isDesktop()) {
      try {
        ScreenBrightnessPlatform.instance.resetApplicationScreenBrightness();
      } catch (_) {}
    }
    unawaited(videoPageController.fullscreen.close());
    keyboardFocus.dispose();
    tabController.dispose();
    TimedShutdownService().cancel();
    super.dispose();
  }

  @override
  void onWindowEnterFullScreen() {
    videoPageController.fullscreen.onDesktopFullscreenChanged(true);
  }

  @override
  void onWindowLeaveFullScreen() {
    videoPageController.fullscreen.onDesktopFullscreenChanged(false);
  }

  void _toggleDebugConsole() {
    setState(() {
      showDebugLog = !showDebugLog;
    });
  }

  Future<void> changeEpisode(int episode,
      {int currentRoad = 0, int offset = 0}) async {
    if (!mounted || _isExiting) {
      return;
    }
    setState(() {
      webviewLogLines.clear();
      showDebugLog = false;
    });
    await videoPageController.changeEpisode(episode,
        currentRoad: currentRoad,
        offset: offset,
        playerController: playerController);
  }

  void _revealCurrentEpisode() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _episodePanelKey.currentState?.revealCurrentEpisode();
    });
  }

  void _toggleSidePanel() => _sidePanelKey.currentState?.toggle();

  void _closeSidePanel() => _sidePanelKey.currentState?.close();

  // Only desktop PiP participates in local navigation.
  void _syncDesktopPipHistory(bool isPip) {
    if (!isDesktop()) return;
    if (isPip && _desktopPipEntry == null) {
      _desktopPipEntry = LocalHistoryEntry(
        impliesAppBarDismissal: false,
        onRemove: () {
          _desktopPipEntry = null;
          if (videoPageController.isPip) {
            videoPageController.isPip = false;
            unawaited(PipUtils.exitDesktopPIPWindow());
          }
        },
      );
      ModalRoute.of(context)!.addLocalHistoryEntry(_desktopPipEntry!);
    } else if (!isPip) {
      _desktopPipEntry?.remove();
      _desktopPipEntry = null;
    }
  }

  void _onBackPressed() {
    unawaited(Navigator.of(context).maybePop());
  }

  void pauseForTimedShutdown() {
    if (playerController.playback.playing) {
      playerController.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          setState(() => _isExiting = true);
          playerController.beginShutdown();
        }
      },
      child: Observer(builder: (context) {
        final bool isPip = videoPageController.isPip;
        return VideoSystemBars(
          fullscreen: videoPageController.isFullscreen,
          isPip: isPip,
          child: Scaffold(
            body: VideoPageLayout(
              fullscreen: videoPageController.isFullscreen,
              isPip: isPip,
              playerBuilder: (context, layout) => ColoredBox(
                color: Colors.black,
                child: Focus(
                  focusNode: keyboardFocus,
                  autofocus: true,
                  // Cleanup resets loading while the route is still visible.
                  child: _isExiting
                      ? const SizedBox.expand()
                      : !videoPageController.hasResolvedSource
                          ? _buildPlayerResolutionPlaceholder()
                          : Observer(builder: (_) => _buildPlayerBody(layout)),
                ),
              ),
              tabs: tabBody,
              sidePanel: VideoSidePanel(
                key: _sidePanelKey,
                fullscreen: videoPageController.isFullscreen,
                disableAnimations: disableAnimations,
                onOpened: _revealCurrentEpisode,
                onClosed: keyboardFocus.requestFocus,
                child: tabBody,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPlayerBody(VideoPlayerLayout layout) {
    final bool playerLoading = playerController.playback.loading;
    return Stack(
      children: [
        Positioned.fill(
          child: Stack(
            children: [
              if (videoPageController.loading ||
                  playerLoading ||
                  videoPageController.errorMessage != null)
                Container(
                  color: Colors.black,
                  child: Observer(builder: (context) {
                    final errorMessage = videoPageController.errorMessage;
                    if (errorMessage != null) {
                      _scheduleAutoSwitch(errorMessage);
                      return MediaErrorWidget(
                        title: '暂时无法播放',
                        errMsg: errorMessage,
                        icon: Icons.videocam_off_outlined,
                      );
                    }
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          LoadingIndicator(
                              color: Theme.of(context)
                                  .colorScheme
                                  .tertiaryContainer),
                          const SizedBox(height: 10),
                          Text(
                            videoPageController.loading
                                ? '视频资源解析中'
                                : '视频资源解析成功, 播放器加载中',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              Visibility(
                visible: (videoPageController.loading || playerLoading) &&
                    showDebugLog,
                child: Container(
                  color: Colors.black,
                  child: Align(
                    alignment: Alignment.center,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: webviewLogLines.length,
                      itemBuilder: (context, index) {
                        return Text(
                          webviewLogLines[index],
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                  ),
                ),
              ),
              Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: EmbeddedNativeControlArea(
                      requireOffset: !videoPageController.isFullscreen,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: _onBackPressed,
                          ),
                          const Expanded(
                              child: dtb.DragToMoveArea(
                                  child: SizedBox(height: 40))),
                          IconButton(
                            icon: const Icon(Icons.refresh_outlined,
                                color: Colors.white),
                            onPressed: () {
                              changeEpisode(
                                  videoPageController.selectedEpisode.episode,
                                  currentRoad:
                                      videoPageController.selectedEpisode.road);
                            },
                          ),
                          if (layout.hasSidePanel)
                            IconButton(
                              onPressed: _toggleSidePanel,
                              icon: const Icon(
                                Icons.menu_open_rounded,
                                color: Colors.white,
                              ),
                            ),
                          IconButton(
                            icon: Icon(
                                showDebugLog
                                    ? Icons.bug_report
                                    : Icons.bug_report_outlined,
                                color: Colors.white),
                            onPressed: _toggleDebugConsole,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned.fill(
          child: playerLoading
              ? const SizedBox.shrink()
              : PlayerItem(
                  fillsWindow: layout.fillsWindow,
                  playerController: playerController,
                  videoPageController: videoPageController,
                  onToggleSidePanel:
                      layout.hasSidePanel ? _toggleSidePanel : null,
                  changeEpisode: changeEpisode,
                  onBackPressed: _onBackPressed,
                  keyboardFocus: keyboardFocus,
                  disableAnimations: disableAnimations,
                  pauseForTimedShutdown: pauseForTimedShutdown,
                ),
        ),
      ],
    );
  }

  Widget get episodePanel => Observer(builder: (context) {
        final downloads = <String, DownloadEpisode>{};
        if (!videoPageController.isOfflineMode) {
          for (final record in downloadController.records) {
            if (record.bangumiId != videoPageController.bangumiItem.id ||
                record.pluginName != videoPageController.currentPlugin.name) {
              continue;
            }
            for (final episode in record.episodes.values) {
              if (episode.episodePageUrl.isNotEmpty) {
                downloads[episode.episodePageUrl] = episode;
              } else if (episode.road >= 0 &&
                  episode.road < videoPageController.roadList.length) {
                // Older records have no URL; only match within their own road.
                final urls = videoPageController.roadList[episode.road].data;
                if (episode.episodeNumber > 0 &&
                    episode.episodeNumber <= urls.length) {
                  downloads[urls[episode.episodeNumber - 1]] = episode;
                }
              }
            }
          }
        }
        return EpisodeSelectionPanel(
          key: _episodePanelKey,
          title: videoPageController.title,
          roads: videoPageController.roadList,
          selectedRoad: videoPageController.selectedEpisode.road,
          selectedEpisode: videoPageController.selectedEpisode.episode,
          downloads: downloads,
          isOffline: videoPageController.isOfflineMode,
          isPlaying: playerController.playback.playing &&
              !playerController.playback.loading &&
              !videoPageController.loading,
          disableAnimations: disableAnimations,
          onEpisodeSelected: (episode, road) {
            if (episode == videoPageController.selectedEpisode.episode &&
                road == videoPageController.selectedEpisode.road) {
              return;
            }
            _closeSidePanel();
            changeEpisode(episode, currentRoad: road);
          },
          onDownload: (road) => showAdaptiveBottomSheet<void>(
            context: context,
            builder: (context) => DownloadEpisodeSheet(
              road: road,
              videoPageController: videoPageController,
            ),
          ),
        );
      });

  Widget get tabBody {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PlayerContentTabs(
            controller: tabController,
            onEpisodesSelected: _revealCurrentEpisode,
          ),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                BealibVideoInfoPanel(
                  bangumiItem: videoPageController.bangumiItem,
                  showRating: GStorage.getSetting<bool>(SettingsKeys.showRating),
                ),
                Column(
                  children: [
                    if (videoPageController.hasResolvedSource)
                      BealibRuleBar(videoPageController: videoPageController),
                    Expanded(
                      child: videoPageController.hasResolvedSource
                          ? episodePanel
                          : _buildEpisodesResolutionPlaceholder(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
