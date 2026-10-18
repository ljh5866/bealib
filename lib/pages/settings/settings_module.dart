import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:bealib/pages/about/about_module.dart';
import 'package:bealib/pages/download/download_page_module.dart';
import 'package:bealib/pages/history/history_module.dart';
import 'package:bealib/pages/logs/logs_page.dart';
import 'package:bealib/pages/plugin_editor/plugin_module.dart';
import 'package:bealib/pages/settings/danmaku/danmaku_module.dart';
import 'package:bealib/pages/settings/decoder_settings.dart';
import 'package:bealib/pages/settings/displaymode_settings.dart';
import 'package:bealib/pages/settings/download_settings.dart';
import 'package:bealib/pages/settings/interface_settings.dart';
import 'package:bealib/pages/settings/keyboard_settings.dart';
import 'package:bealib/pages/settings/player_settings.dart';
import 'package:bealib/pages/settings/proxy/proxy_module.dart';
import 'package:bealib/pages/settings/renderer_settings.dart';
import 'package:bealib/pages/settings/settings_page.dart';
import 'package:bealib/pages/settings/storage_settings.dart';
import 'package:bealib/pages/settings/thanks_page.dart';
import 'package:bealib/pages/settings/super_resolution_settings.dart';
import 'package:bealib/pages/settings/sync/bangumi_sync_page.dart';
import 'package:bealib/pages/settings/sync/sync_settings_page.dart';
import 'package:bealib/pages/settings/sync/webdav_server_page.dart';
import 'package:bealib/pages/settings/sync/webdav_sync_page.dart';
import 'package:bealib/pages/settings/theme_settings_page.dart';
import 'package:bealib/pages/settings/update_settings.dart';
import 'package:bealib/request/config/api_endpoints.dart';
import 'package:bealib/services/sync/danmaku_shield_sync_service.dart';

final settingsModule = createModule(
  path: '/settings',
  register: (c) {
    c.route(
      '/',
      child: (context, state) => SettingsPage(location: state.uri.path),
      children: (sub) {
        sub
          ..route('/', child: (context, state) => const SettingsIndexPage())
          ..route('/sync', child: (context, state) => const SyncSettingsPage())
          ..route('/bangumi/',
              child: (context, state) => const BangumiSyncPage())
          ..route('/webdav/',
              child: (context, state) => WebDavSyncPage(
                    danmakuShieldSync: inject<DanmakuShieldSyncService>(),
                  ))
          ..route('/webdav/editor',
              child: (context, state) => const WebDavServerPage())
          ..route(
            '/update',
            child: (context, state) => const UpdateSettingsPage(),
          )
          ..route('/storage',
              child: (context, state) => const StorageSettingsPage())
          ..route('/storage/logs', child: (context, state) => const LogsPage())
          ..route('/theme',
              child: (context, state) => const ThemeSettingsPage())
          ..route(
            '/theme/display',
            child: (context, state) => const SetDisplayMode(),
          )
          ..route(
            '/keyboard',
            child: (context, state) => const KeyboardSettingsPage(),
          )
          ..route('/player',
              child: (context, state) => const PlayerSettingsPage())
          ..route(
            '/player/decoder',
            child: (context, state) => const DecoderSettings(),
          )
          ..route(
            '/player/renderer',
            child: (context, state) => const RendererSettings(),
          )
          ..route(
            '/interface',
            child: (context, state) => const InterfaceSettingsPage(),
          )
          ..module(proxyModule)
          ..route(
            '/player/super',
            child: (context, state) => const SuperResolutionSettings(),
          )
          ..module(aboutModule)
          ..module(pluginModule)
          ..module(danmakuModule)
          ..route(
            '/download-settings',
            child: (context, state) => const DownloadSettingsPage(),
          )
          ..route(
            '/thanks',
            child: (context, state) => const ThanksPage(),
          );
      },
    );
    c
      // Root route: the license browser must cover the settings shell.
      ..route(
        '/about/license',
        child: (context, state) => const LicensePage(
          applicationName: 'Bealib',
          applicationVersion: ApiEndpoints.version,
          applicationLegalese: 'Bealib · GNU General Public License v3.0',
        ),
      )
      ..module(historyModule)
      ..module(downloadModule);
  },
);
