import 'dart:io';

import 'package:flutter/material.dart';

import 'package:bealib/bean/dialog/dialog_helper.dart';
import 'package:bealib/bean/settings/settings_detail_scaffold.dart';
import 'package:bealib/bean/settings/settings_list.dart';
import 'package:bealib/bean/widget/loading_indicator.dart';
import 'package:bealib/services/download/download_directory_service.dart';
import 'package:bealib/services/storage/storage.dart';
import 'package:bealib/utils/file_system.dart';

class DownloadSettingsPage extends StatefulWidget {
  const DownloadSettingsPage({super.key});

  @override
  State<DownloadSettingsPage> createState() => _DownloadSettingsPageState();
}

class _DownloadSettingsPageState extends State<DownloadSettingsPage> {
  final _directoryService = DownloadDirectoryService();
  late int parallelEpisodes;
  String downloadDirectory = '';
  String defaultDownloadDirectory = '';
  bool isSelectingDirectory = false;

  @override
  void initState() {
    super.initState();
    parallelEpisodes =
        GStorage.getSetting(SettingsKeys.downloadParallelEpisodes);
    downloadDirectory = _directoryService.customDirectory;
    _loadDefaultDownloadDirectory();
  }

  bool get _hasCustomDirectory => downloadDirectory.isNotEmpty;

  String get _effectiveDownloadDirectory =>
      _hasCustomDirectory ? downloadDirectory : defaultDownloadDirectory;

  Future<void> _loadDefaultDownloadDirectory() async {
    final directory = await getDefaultDownloadDirectory();
    if (!mounted) return;
    setState(() {
      defaultDownloadDirectory = directory;
    });
  }

  Future<void> _selectDownloadDirectory() async {
    if (isSelectingDirectory) return;

    setState(() => isSelectingDirectory = true);
    try {
      final selectedPath = await _directoryService.selectDirectory();
      if (selectedPath == null) return;
      if (mounted) {
        setState(() => downloadDirectory = selectedPath);
      }
      BealibDialog.showToast(message: '下载位置已更新，仅对新下载生效');
    } on DownloadDirectoryException catch (e) {
      BealibDialog.showToast(message: e.message);
    } on FileSystemException catch (e) {
      BealibDialog.showToast(message: '无法写入该目录: ${e.message}');
    } catch (e) {
      BealibDialog.showToast(message: '选择下载位置失败: $e');
    } finally {
      if (mounted) {
        setState(() => isSelectingDirectory = false);
      }
    }
  }

  Future<void> _resetDownloadDirectory() async {
    await _directoryService.resetDirectory();
    if (mounted) {
      setState(() => downloadDirectory = '');
    }
    BealibDialog.showToast(message: '已恢复默认下载位置，仅对新下载生效');
  }

  @override
  Widget build(BuildContext context) {
    return SettingsDetailScaffold(
      title: const Text('下载设置'),
      body: SettingsList(
        sections: [
          // 需求：下载设置 = 自定义下载目录 + 设置下载集数
          SettingsSection(
            title: Text('下载目录'),
            tiles: [
              SettingsTile(
                leading: Icons.folder_rounded,
                title: Text('自定义下载目录'),
                description: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _effectiveDownloadDirectory.isEmpty
                          ? '正在读取默认位置...'
                          : _effectiveDownloadDirectory,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _hasCustomDirectory
                          ? '当前使用自定义下载位置，修改后仅对新下载生效'
                          : '当前使用默认下载位置，修改后仅对新下载生效',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
                trailing: isSelectingDirectory
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: LoadingIndicator(),
                      )
                    : _hasCustomDirectory
                        ? IconButton(
                            tooltip: '恢复默认',
                            icon: const Icon(Icons.restore_rounded),
                            onPressed: _resetDownloadDirectory,
                          )
                        : null,
                onPressed: (_) => _selectDownloadDirectory(),
              ),
            ],
          ),
          SettingsSection(
            title: Text('下载集数'),
            tiles: [
              SettingsSliderTile(
                leading: Icons.video_library_rounded,
                title: Text('同时下载集数'),
                description: Text('并行下载的剧集数量'),
                value: parallelEpisodes.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                valueLabel: '$parallelEpisodes 集',
                onChanged: (value) {
                  setState(() => parallelEpisodes = value.toInt());
                  GStorage.putSetting(
                    SettingsKeys.downloadParallelEpisodes,
                    parallelEpisodes,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
