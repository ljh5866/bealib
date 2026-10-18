import 'package:flutter/material.dart';

import 'package:bealib/bean/dialog/dialog_helper.dart';
import 'package:bealib/bean/settings/settings_detail_scaffold.dart';
import 'package:bealib/bean/settings/settings_list.dart';
import 'package:bealib/request/config/api_endpoints.dart';
import 'package:bealib/services/storage/storage.dart';
import 'package:bealib/services/update/auto_updater.dart';

class UpdateSettingsPage extends StatefulWidget {
  const UpdateSettingsPage({super.key});

  @override
  State<UpdateSettingsPage> createState() => _UpdateSettingsPageState();
}

class _UpdateSettingsPageState extends State<UpdateSettingsPage> {
  bool _autoUpdate = GStorage.getSetting(SettingsKeys.autoUpdate);
  bool _pluginUpdate =
      GStorage.getSetting(SettingsKeys.checkPluginUpdateOnStartup);
  bool _checking = false;

  Future<void> _checkUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      await AutoUpdater().manualCheckForUpdates();
    } catch (_) {
      BealibDialog.showToast(message: '检查更新失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => SettingsDetailScaffold(
        title: const Text('更新设置'),
        body: SettingsList(
          sections: [
            SettingsSection(
              title: const Text('更新来源'),
              tiles: [
                SettingsCategoryTile(
                  icon: Icons.public_rounded,
                  title: 'GitHub（固定）',
                  description:
                      '当前版本 ${ApiEndpoints.version} · 点击检查 GitHub Releases',
                  onTap: _checkUpdate,
                ),
              ],
            ),
            SettingsSection(
              title: const Text('启动时检查更新'),
              tiles: [
                SettingsTile.switchTile(
                  leading: Icons.update_rounded,
                  title: const Text('应用更新'),
                  initialValue: _autoUpdate,
                  onToggle: (value) {
                    setState(() => _autoUpdate = value ?? !_autoUpdate);
                    GStorage.putSetting(SettingsKeys.autoUpdate, _autoUpdate);
                  },
                ),
                SettingsTile.switchTile(
                  leading: Icons.extension_rounded,
                  title: const Text('规则更新'),
                  initialValue: _pluginUpdate,
                  onToggle: (value) {
                    setState(() => _pluginUpdate = value ?? !_pluginUpdate);
                    GStorage.putSetting(
                      SettingsKeys.checkPluginUpdateOnStartup,
                      _pluginUpdate,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      );
}
