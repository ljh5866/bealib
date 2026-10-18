import 'package:flutter_modular/flutter_modular.dart';
import 'package:bealib/pages/collect/collect_controller.dart';
import 'package:bealib/pages/download/download_controller.dart';
import 'package:bealib/pages/history/history_controller.dart';
import 'package:bealib/pages/my/my_controller.dart';
import 'package:bealib/plugins/plugins_controller.dart';
import 'package:bealib/repositories/collect_crud_repository.dart';
import 'package:bealib/repositories/collect_repository.dart';
import 'package:bealib/repositories/download_repository.dart';
import 'package:bealib/repositories/danmaku_shield_repository.dart';
import 'package:bealib/repositories/history_repository.dart';
import 'package:bealib/repositories/search_history_repository.dart';
import 'package:bealib/services/download/download_manager.dart';
import 'package:bealib/services/player/audio_controller.dart';
import 'package:bealib/services/player/history_playback_service.dart';
import 'package:bealib/services/shaders/shader_asset_service.dart';
import 'package:bealib/services/sync/danmaku_shield_sync_service.dart';
import 'package:bealib/services/sync/webdav.dart';

/// Root-owned application data and cross-feature coordinators.
///
/// This module intentionally has no path, so its registrations live for the
/// whole application. Page and feature-local state belongs in route `provide`
/// callbacks or path-bearing modules instead.
final coreModule = createModule(
  register: (c) {
    c
      // Repository layer.
      ..addSingleton<ICollectRepository>(CollectRepository.new)
      ..addSingleton<ISearchHistoryRepository>(SearchHistoryRepository.new)
      ..addSingleton<ICollectCrudRepository>(CollectCrudRepository.new)
      ..addSingleton<IHistoryRepository>(HistoryRepository.new)
      ..addSingleton<IDownloadRepository>(DownloadRepository.new)
      ..addSingleton<IDanmakuShieldRepository>(DanmakuShieldRepository.new)
      // Service layer.
      ..addSingleton<IDownloadManager>(DownloadManager.new)
      ..addSingleton<AudioController>(AudioController.new)
      ..addSingleton<HistoryPlaybackService>(HistoryPlaybackService.new)
      ..addSingleton<ShaderAssetService>(ShaderAssetService.new)
      ..addSingleton<WebDav>(WebDav.new)
      ..addSingleton<DanmakuShieldSyncService>(DanmakuShieldSyncService.new)
      // Cross-feature state and coordinators.
      ..addSingleton<PluginsController>(PluginsController.new)
      ..addSingleton<CollectController>(CollectController.new)
      ..addSingleton<HistoryController>(HistoryController.new)
      ..addSingleton<MyController>(MyController.new)
      ..addSingleton<DownloadController>(DownloadController.new);
  },
);
