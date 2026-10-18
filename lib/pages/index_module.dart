import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:bealib/bean/widget/error_widget.dart';
import 'package:bealib/bean/widget/image_preview.dart';
import 'package:bealib/pages/download/download_page_module.dart';
import 'package:bealib/pages/info/info_module.dart';
import 'package:bealib/pages/init_page.dart';
import 'package:bealib/pages/onboarding/onboarding_page.dart';
import 'package:bealib/pages/route_error_page.dart';
import 'package:bealib/pages/search/search_module.dart';
import 'package:bealib/pages/settings/settings_module.dart';
import 'package:bealib/pages/shell/shell_page.dart';
import 'package:bealib/pages/video/video_module.dart';
import 'package:bealib/plugins/plugins_controller.dart';
import 'package:bealib/pages/collect/collect_controller.dart';
import 'package:bealib/pages/my/my_controller.dart';
import 'package:bealib/pages/download/download_controller.dart';
import 'package:bealib/services/shaders/shader_asset_service.dart';
import 'package:bealib/services/sync/danmaku_shield_sync_service.dart';

final _imagePreviewTransition = CustomTransition(
  duration: const Duration(milliseconds: 220),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    return FadeTransition(opacity: animation, child: child);
  },
);

/// 根路由。
///
/// Bealib 的信息架构只有两个一级页面（首页 / 设置），由 [ShellPage] 用一个
/// IndexedStack + 自绘胶囊导航承载；详情、视频、搜索、设置子页仍走
/// flutter_modular 的既有路由，因此子页可以完整复用上游实现。
final indexModule = createModule(
  register: (c) {
    c
      ..route(
        '/',
        child: (context, state) => InitPage(
          pluginsController: inject<PluginsController>(),
          collectController: inject<CollectController>(),
          shaderAssetService: inject<ShaderAssetService>(),
          myController: inject<MyController>(),
          downloadController: inject<DownloadController>(),
          danmakuShieldSync: inject<DanmakuShieldSyncService>(),
        ),
        transition: TransitionType.none,
      )
      ..route(
        '/onboarding',
        child: (context, state) => OnboardingPage(
          pluginsController: inject<PluginsController>(),
          myController: inject<MyController>(),
        ),
        transition: TransitionType.none,
      )
      ..route(
        '/shell',
        child: (context, state) => const ShellPage(),
        transition: TransitionType.none,
      )
      ..route(
        '/error',
        child: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Bealib')),
          body: const GeneralErrorWidget(
            title: '初始化失败',
            errMsg: '请重新启动应用后再试。',
          ),
        ),
      )
      ..module(videoModule)
      ..route(
        ImageViewer.routePath,
        child: (context, state) {
          final args = state.arguments;
          if (args is! ImageViewerRouteArgs) {
            return const RouteErrorPage(message: '图片预览参数无效，请返回后重试。');
          }
          return ImageViewer(
            imageUrls: args.imageUrls,
            initialIndex: args.initialIndex,
            heroTag: args.heroTag,
          );
        },
        transition: _imagePreviewTransition,
      )
      ..module(downloadModule)
      ..module(infoModule)
      ..module(settingsModule)
      ..module(searchModule);
  },
);
