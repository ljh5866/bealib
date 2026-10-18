import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:bealib/bean/dialog/dialog_helper.dart';
import 'package:bealib/bean/settings/settings_detail_scaffold.dart';
import 'package:bealib/bean/settings/settings_list.dart';
import 'package:bealib/pages/plugin_editor/rule_dialogs.dart';
import 'package:bealib/plugins/plugins.dart';
import 'package:bealib/plugins/plugins_controller.dart';
import 'package:bealib/services/logging/logger.dart';
import 'package:bealib/services/plugin/plugin_import_parser.dart';

/// 规则设置 → 增添规则。
///
/// 只保留两种方式：导入（剪贴板/链接、本地文件）与自己写（模板编辑器）。
/// 仓库规则默认全部自动安装，不再提供规则仓库浏览/我的规则管理入口。
class RuleAddPage extends StatelessWidget {
  const RuleAddPage({super.key, required this.controller});

  final PluginsController controller;

  Future<void> _import(BuildContext context) async {
    final source = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.content_paste_rounded),
              title: const Text('从剪贴板 / 链接导入'),
              subtitle: const Text('粘贴规则 JSON 或规则分享链接'),
              onTap: () => Navigator.of(context).pop(true),
            ),
            ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: const Text('从文件导入'),
              subtitle: const Text('读取本地 JSON 规则文件'),
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || source == null) return;
    if (source) {
      String initialValue = '';
      try {
        initialValue =
            (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
      } catch (_) {
        initialValue = '';
      }
      if (context.mounted) {
        await showRuleImportDialog(context, controller,
            initialValue: initialValue);
      }
    } else {
      await _importFromFile();
    }
  }

  Future<void> _importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (result == null) return;
      final file = result.files.single;
      final bytes = file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) throw const FileSystemException('无法读取所选文件');
      final parsed = PluginImportParser.parse(utf8.decode(bytes));
      if (parsed.plugins.isEmpty) {
        BealibDialog.showToast(
          message: parsed.failures.isEmpty ? '文件中没有可导入的规则' : parsed.failures.first,
        );
        return;
      }
      await controller.updatePlugins(parsed.plugins);
      BealibDialog.showToast(
        message: '已导入 ${parsed.plugins.length} 条规则，'
            '跳过重复 ${parsed.duplicateCount} 条，失败 ${parsed.failureCount} 条',
      );
    } catch (error, stackTrace) {
      BealibLogger()
          .e('Plugin: failed to import rules from file', error: error, stackTrace: stackTrace);
      BealibDialog.showToast(message: '导入规则文件失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SettingsDetailScaffold(
      title: const Text('增添规则'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            '仓库规则已默认全部安装并保持更新。这里只用于导入单条规则，或自己编写规则。',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 20),
          SettingsSection(
            title: const Text('增添方式'),
            tiles: [
              SettingsCategoryTile(
                icon: Icons.file_download_rounded,
                title: '导入规则',
                description: '从剪贴板 / 链接粘贴规则，或选择本地 JSON 文件',
                onTap: () => _import(context),
              ),
              SettingsCategoryTile(
                icon: Icons.edit_note_rounded,
                title: '自己写规则',
                description: '从模板新建，使用编辑器编写采集规则',
                onTap: () => context.pushNamed(
                  '/settings/plugin/editor',
                  arguments: Plugin.fromTemplate(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '当前已安装 ${controller.pluginList.length} 条规则',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
