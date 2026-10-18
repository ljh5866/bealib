import 'package:flutter/material.dart';

import 'package:bealib/bean/dialog/dialog_helper.dart';
import 'package:bealib/bean/settings/settings_detail_scaffold.dart';
import 'package:bealib/bean/settings/settings_list.dart';
import 'package:bealib/request/config/api_endpoints.dart';
import 'package:bealib/services/update/auto_updater.dart';

class UpdateSettingsPage extends StatefulWidget {
  const UpdateSettingsPage({super.key});

  @override
  State<UpdateSettingsPage> createState() => _UpdateSettingsPageState();
}

class _UpdateSettingsPageState extends State<UpdateSettingsPage> {
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
              title: const Text('应用更新'),
              tiles: [
                SettingsCategoryTile(
                  icon: Icons.system_update_alt_rounded,
                  title: _checking ? '正在检查…' : '检查更新',
                  description:
                      '当前版本 ${ApiEndpoints.version} · 更新来自 GitHub Releases',
                  onTap: _checkUpdate,
                ),
              ],
            ),
          ],
        ),
      );
}
