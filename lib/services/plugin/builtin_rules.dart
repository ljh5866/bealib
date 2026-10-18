import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:bealib/plugins/plugins.dart';
import 'package:bealib/services/logging/logger.dart';

/// 随 App 内置的规则（来自 `assets/rules/*.json`）。
///
/// 首次启动会自动安装；内置文件里的 `version` 高于已安装版本时会自动更新。
/// 用户不需要手动导入，也不受「仓库规则」同步影响。
class BuiltinRules {
  const BuiltinRules._();

  static const List<String> assetPaths = <String>[
    'assets/rules/agedm.json',
  ];

  static Future<List<Plugin>> load() async {
    final List<Plugin> plugins = <Plugin>[];
    for (final String path in assetPaths) {
      try {
        final String raw = await rootBundle.loadString(path);
        final Object? decoded = json.decode(raw);
        if (decoded is Map<String, dynamic>) {
          plugins.add(Plugin.fromJson(decoded));
        } else if (decoded is List) {
          for (final Object? item in decoded) {
            if (item is Map<String, dynamic>) {
              plugins.add(Plugin.fromJson(item));
            }
          }
        }
      } catch (error) {
        BealibLogger().w(
          'BuiltinRules: failed to load $path',
          error: error,
        );
      }
    }
    return plugins;
  }
}
