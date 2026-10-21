import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:bealib/bean/dialog/dialog_helper.dart';
import 'package:bealib/bean/dialog/update_available_dialog.dart';
import 'package:bealib/request/clients/download_http_client.dart';
import 'package:bealib/request/core/network_exception.dart';
import 'package:bealib/request/config/api_endpoints.dart';
import 'package:bealib/services/logging/logger.dart';
import 'package:bealib/services/update/update_download_source.dart';
import 'package:bealib/services/update/update_downloader.dart';
import 'package:bealib/services/update/update_policy.dart';
import 'package:bealib/services/storage/storage.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bealib/utils/device.dart';
import 'package:bealib/utils/version.dart';

enum InstallationType {
  windowsMsix('MSIX'),
  windowsPortable('ZIP'),
  linuxDeb('DEB'),
  linuxTar('TAR'),
  macosDmg('DMG'),
  androidApk('APK'),
  ios('IPA'),
  unknown('未知类型');

  const InstallationType(this.label);

  final String label;

  /// Types without a matching asset are updated from the release page.
  bool get downloadsInApp => getUpdateFilePatterns(this).isNotEmpty;
}

class UpdateInfo {
  final String version;
  final String description;
  final String downloadUrl;
  final String releaseNotes;
  final String publishedAt;
  final InstallationType? installationType;
  final List<InstallationType> availableInstallationTypes;
  final List<dynamic> assets;
  final bool forceUpdate;
  final String forceReason;

  UpdateInfo({
    required this.version,
    required this.description,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.publishedAt,
    this.installationType,
    this.availableInstallationTypes = const [],
    this.assets = const [],
    this.forceUpdate = false,
    this.forceReason = '',
  });
  InstallationType get recommendedInstallationType {
    if (availableInstallationTypes.isNotEmpty) {
      return availableInstallationTypes.first;
    }
    return installationType ?? InstallationType.unknown;
  }
}

Map<String, dynamic>? getUpdateAssetForType(
    List<dynamic> assets, InstallationType type) {
  final patterns = getUpdateFilePatterns(type).map((p) => p.toLowerCase());
  if (patterns.isEmpty) return null;
  final matches = <Map<String, dynamic>>[
    for (final asset in assets.whereType<Map<String, dynamic>>())
      if (patterns.every(
          (pattern) => ((asset['name'] as String?) ?? '').toLowerCase().contains(pattern)))
        asset,
  ];
  if (matches.isEmpty) return null;
  if (type != InstallationType.androidApk || matches.length == 1) {
    return matches.first;
  }
  // 多 APK 资产时优先通用包，其次 arm64，最后取文件名最短的。
  for (final keyword in const ['universal', 'arm64-v8a', 'arm64']) {
    for (final asset in matches) {
      final name = ((asset['name'] as String?) ?? '').toLowerCase();
      if (name.contains(keyword)) return asset;
    }
  }
  matches.sort((a, b) => ((a['name'] as String?) ?? '')
      .length
      .compareTo(((b['name'] as String?) ?? '').length));
  return matches.first;
}

String getUpdateFileHashFromAsset(Map<String, dynamic> asset) {
  final digest = asset['digest'] as String? ?? '';
  if (digest.startsWith('sha256:')) {
    return digest.substring(7);
  }
  return '';
}

List<String> getUpdateFilePatterns(InstallationType installationType) {
  switch (installationType) {
    case InstallationType.windowsMsix:
      return ['windows', '.msix'];
    case InstallationType.windowsPortable:
      return ['windows', '.zip'];
    case InstallationType.macosDmg:
      return ['macos', '.dmg'];
    case InstallationType.androidApk:
      // 资产名可能不含 android（如 Bealib-0.1.0-release.apk）。
      return ['.apk'];
    case InstallationType.linuxDeb:
    case InstallationType.linuxTar:
    case InstallationType.ios:
    case InstallationType.unknown:
      return [];
  }
}

class AutoUpdater {
  static final AutoUpdater _instance = AutoUpdater._internal();

  factory AutoUpdater() => _instance;

  AutoUpdater._internal();

  final DownloadHttpClient _downloadClient = DownloadHttpClient.instance;

  /// 仓库还没有发布任何 Release（GitHub 返回 404/403）。
  bool _noPublishedRelease = false;

  /// 最近一次拉取到的版本策略（用于强制更新/停用判断）。
  UpdatePolicy? lastPolicy;

  List<InstallationType> _detectAvailableInstallationTypes() {
    if (Platform.isWindows) {
      return [InstallationType.windowsMsix, InstallationType.windowsPortable];
    }
    if (Platform.isLinux) {
      return [InstallationType.linuxDeb, InstallationType.linuxTar];
    }
    if (Platform.isMacOS) return [InstallationType.macosDmg];
    if (Platform.isIOS) return [InstallationType.ios];
    if (Platform.isAndroid) return [InstallationType.androidApk];
    return [InstallationType.unknown];
  }

  Future<UpdateInfo?> checkForUpdates() async {
    _noPublishedRelease = false;
    try {
      final data = await _latestRelease();

      if (!data.containsKey('tag_name')) {
        _noPublishedRelease = data.isEmpty;
        return null;
      }

      final remoteVersion = data['tag_name'] as String;
      final currentVersion = ApiEndpoints.version;

      UpdatePolicy? policy;
      try {
        policy = await UpdatePolicyService.instance.fetch();
      } catch (error) {
        BealibLogger().w('Update: load policy failed', error: error);
      }
      lastPolicy = policy;
      final forceUpdate = policy?.blocks(currentVersion) ?? false;
      final forceReason =
          forceUpdate ? (policy?.reasonFor(currentVersion) ?? '') : '';

      if (needUpdate(currentVersion, remoteVersion)) {
        final availableTypes = _detectAvailableInstallationTypes();

        return UpdateInfo(
          version: remoteVersion,
          description: data['body'] ?? '发现新版本',
          downloadUrl: '',
          releaseNotes: data['html_url'] ?? '',
          publishedAt: data['published_at'] ?? '',
          installationType: availableTypes.first,
          availableInstallationTypes: availableTypes,
          assets: data['assets'] ?? [],
          forceUpdate: forceUpdate,
          forceReason: forceReason,
        );
      }

      return null;
    } catch (e) {
      BealibLogger().e('Update: check for updates failed', error: e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _latestRelease() async {
    try {
      final raw = await _downloadClient.getPlain(
        ApiEndpoints.updateCheckUrl,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'Bealib-Android',
        },
        receiveTimeout: const Duration(seconds: 20),
      );
      if (raw.trim().isEmpty) return <String, dynamic>{};
      final data = json.decode(raw);
      if (data is! Map) {
        throw Exception('Invalid update response');
      }
      return Map<String, dynamic>.from(data);
    } on NetworkException catch (e) {
      // 仓库还没有 Release 时 GitHub 返回 404：视为「暂无新版本」。
      if (e.type == NetworkExceptionType.badResponse &&
          (e.statusCode == 404 || e.statusCode == 403)) {
        BealibLogger().i('Update: no release published yet (${e.statusCode})');
        return <String, dynamic>{};
      }
      rethrow;
    }
  }

  Future<void> autoCheckForUpdates() async {
    final autoUpdate = GStorage.getSetting(SettingsKeys.autoUpdate);
    if (!autoUpdate) return;

    try {
      final updateInfo = await checkForUpdates();
      if (updateInfo != null) {
        _showUpdateDialog(updateInfo, isAutoCheck: true);
      } else if (lastPolicy?.blocks(ApiEndpoints.version) ?? false) {
        await _showForceBlockedDialog();
      }
    } catch (e) {
      BealibLogger().w('Update: auto check for updates failed', error: e);
    }
  }

  Future<void> manualCheckForUpdates() async {
    try {
      final updateInfo = await checkForUpdates();
      if (updateInfo != null) {
        _showUpdateDialog(updateInfo, isAutoCheck: false);
      } else if (lastPolicy?.blocks(ApiEndpoints.version) ?? false) {
        await _showForceBlockedDialog();
      } else if (_noPublishedRelease) {
        BealibDialog.showToast(
            message: '仓库 ${ApiEndpoints.updateRepo} 暂无 Release，请先在 GitHub 发布');
      } else {
        BealibDialog.showToast(message: '当前已经是最新版本！');
      }
    } catch (e) {
      BealibDialog.showToast(message: '检查更新失败');
    }
  }

  Future<void> _showForceBlockedDialog() async {
    final policy = lastPolicy;
    if (policy == null) return;
    await BealibDialog.show<void>(
      clickMaskDismiss: false,
      builder: (context) => UpdateBlockedDialog(
        reason: policy.reasonFor(ApiEndpoints.version),
      ),
    );
  }

  Future<void> _showUpdateDialog(UpdateInfo updateInfo,
      {bool isAutoCheck = false}) async {
    final force = updateInfo.forceUpdate;
    var disableAutoUpdate = false;
    // 强制更新不允许取消：弹窗被系统返回键等方式关闭时，短暂等待后重新弹出。
    for (var attempt = 0; attempt < 5; attempt++) {
      final choice = await BealibDialog.show<UpdateDialogChoice>(
        clickMaskDismiss: !force,
        builder: (context) => UpdateAvailableDialog(
          updateInfo: updateInfo,
          force: force,
          forceReason: updateInfo.forceReason,
          onDisableAutoUpdateChanged: isAutoCheck && !force
              ? (value) => disableAutoUpdate = value
              : null,
        ),
      );
      if (disableAutoUpdate) {
        GStorage.putSetting(SettingsKeys.autoUpdate, false);
        BealibDialog.showToast(message: '已关闭自动更新');
      }
      if (choice != null) {
        _downloadUpdateWithType(updateInfo, choice.type, choice.source);
        return;
      }
      if (!force) return;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  Future<void> _downloadUpdateWithType(
      UpdateInfo updateInfo, InstallationType selectedType,
      UpdateDownloadSource source) async {
    try {
      if (!selectedType.downloadsInApp) {
        String releaseUrl = updateInfo.releaseNotes;
        if (releaseUrl.isEmpty) {
          releaseUrl = ApiEndpoints.latestApp;
        }
        launchUrl(Uri.parse(releaseUrl), mode: LaunchMode.externalApplication);
        return;
      }

      final asset = getUpdateAssetForType(updateInfo.assets, selectedType);
      final downloadUrl = getUpdateDownloadUrlFromAsset(asset, source);
      if (asset == null || downloadUrl.isEmpty) {
        BealibDialog.showToast(message: '没有找到 ${selectedType.label} 的下载链接');
        return;
      }

      final expectedHash = getUpdateFileHashFromAsset(asset);
      final downloadInfo = UpdateInfo(
        version: updateInfo.version,
        description: updateInfo.description,
        downloadUrl: downloadUrl,
        releaseNotes: updateInfo.releaseNotes,
        publishedAt: updateInfo.publishedAt,
        installationType: selectedType,
        availableInstallationTypes: [selectedType],
        assets: updateInfo.assets,
      );

      _downloadUpdate(
        downloadInfo,
        expectedHash,
        force: updateInfo.forceUpdate,
      );
    } catch (e) {
      BealibDialog.showToast(message: '下载失败: ${e.toString()}');
      BealibLogger().e('Update: download update failed', error: e);
    }
  }

  Future<void> _downloadUpdate(
      UpdateInfo updateInfo, String expectedHash,
      {bool force = false}) async {
    if (_downloadDialogs.isRunning) return;
    await _downloadDialogs.run((task) async {
      _downloadProgress.value = 0;
      final cancelToken = CancelToken();
      final downloadPath = await task.loading(
        action: () => _downloadFile(updateInfo.downloadUrl, updateInfo.version,
            expectedHash, cancelToken),
        onCancel: cancelToken.cancel,
        builder: (context) {
          return PopScope(
            canPop: !force,
            child: AlertDialog(
              title: const Text('正在下载更新'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<double>(
                    valueListenable: _downloadProgress,
                    builder: (context, value, child) {
                      return Column(
                        children: [
                          LinearProgressIndicator(value: value),
                          const SizedBox(height: 8),
                          Text('${(value * 100).toStringAsFixed(1)}%'),
                        ],
                      );
                    },
                  ),
                ],
              ),
              actions: [
                if (!force)
                  TextButton(
                    onPressed: () => BealibDialog.dismiss(context: context),
                    child: const Text('取消'),
                  ),
              ],
            ),
          );
        },
      );

      _showDownloadCompleteDialog(downloadPath, updateInfo, force: force);
    }, onError: (e, stackTrace) {
      final errorMessage = getUpdateDownloadErrorMessage(e);

      if (force) {
        _showForceDownloadErrorDialog(
          errorMessage,
          retry: () => _downloadUpdate(updateInfo, expectedHash, force: true),
        );
      } else {
        BealibDialog.show(
          builder: (context) {
            return AlertDialog(
              title: const Text('下载失败'),
              content: Text(errorMessage),
              actions: [
                TextButton(
                  onPressed: () => BealibDialog.dismiss(context: context),
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      }

      BealibLogger().e(
          'Update: download failed | source=${updateInfo.downloadUrl} | '
          '${describeUpdateDownloadError(e, stackTrace)}',
          error: e);
    });
  }

  Future<void> _showForceDownloadErrorDialog(
    String message, {
    required Future<void> Function() retry,
  }) async {
    final bool? shouldRetry = await BealibDialog.show<bool>(
      clickMaskDismiss: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('下载失败'),
            content: Text(message),
            actions: [
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                onPressed: () => launchUrl(
                  Uri.parse(ApiEndpoints.officialWebsite),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.public_rounded, size: 18),
                label: const Text('访问官网'),
              ),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                onPressed: () =>
                    BealibDialog.dismiss(context: context, popWith: true),
                child: const Text('重试'),
              ),
            ],
          ),
        );
      },
    );
    if (shouldRetry == true) {
      await retry();
    }
  }

  final ValueNotifier<double> _downloadProgress = ValueNotifier(0.0);
  final _downloadDialogs = BealibDialogController();

  void _showDownloadCompleteDialog(String filePath, UpdateInfo updateInfo,
      {bool force = false}) {
    BealibDialog.show(
      clickMaskDismiss: !force,
      builder: (context) {
        return PopScope(
          canPop: !force,
          child: AlertDialog(
            title: const Text('下载完成'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('新版本 ${updateInfo.version} 已下载完成'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '安装过程中应用将会退出',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '文件位置:',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        filePath,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (!force)
                TextButton(
                  onPressed: () => BealibDialog.dismiss(),
                  child: Text(
                    '稍后安装',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                ),
              if (!force && isDesktop())
                TextButton(
                  onPressed: () {
                    BealibDialog.dismiss(context: context);
                    _revealInFileManager(filePath);
                  },
                  child: const Text('打开文件夹'),
                ),
              TextButton(
                onPressed: () {
                  BealibDialog.dismiss();
                  _installUpdate(
                      filePath, updateInfo.recommendedInstallationType);
                },
                child: const Text('立即安装'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String> _downloadFile(String url, String version, String expectedHash,
      CancelToken cancelToken) async {
    final tempDir = await getTemporaryDirectory();
    return downloadUpdateFile(
      url: url,
      filePath: '${tempDir.path}/${_getFileNameFromUrl(url, version)}',
      expectedHash: expectedHash,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        _downloadProgress.value = total > 0 ? received / total : 0;
      },
    );
  }

  void _installUpdate(
      String filePath, InstallationType installationType) async {
    try {
      BealibDialog.showToast(message: '准备安装更新，应用即将退出...');

      await Future.delayed(const Duration(seconds: 2));

      if (Platform.isWindows) {
        if (installationType == InstallationType.windowsMsix) {
          final Uri fileUri = Uri.file(filePath);
          if (await canLaunchUrl(fileUri)) {
            await launchUrl(fileUri);
          } else {
            throw 'Could not launch $fileUri';
          }
        } else {
          await Process.start('explorer.exe', [filePath], runInShell: true);
        }
        await Future.delayed(const Duration(seconds: 1));
        exit(0);
      } else if (Platform.isMacOS) {
        if (filePath.endsWith('.dmg')) {
          await Process.start('open', [filePath]);
          exit(0);
        }
      } else if (Platform.isAndroid) {
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          BealibDialog.showToast(message: '无法打开安装文件: ${result.message}');
          return;
        }
      }
    } catch (e) {
      BealibDialog.showToast(message: '启动安装程序失败: ${e.toString()}');
      BealibLogger().e('Update: launch installer failed', error: e);
    }
  }

  void _revealInFileManager(String filePath) async {
    try {
      final type = await FileSystemEntity.type(filePath);
      String targetDirOrFile;
      if (type == FileSystemEntityType.notFound) {
        BealibDialog.showToast(message: '文件或目录不存在');
        return;
      } else if (type == FileSystemEntityType.directory) {
        targetDirOrFile = filePath;
      } else {
        targetDirOrFile = File(filePath).parent.path;
      }

      if (Platform.isWindows) {
        if (type == FileSystemEntityType.file) {
          final arg = '/select,${filePath.replaceAll('/', r'\')}';
          await Process.start('explorer.exe', [arg], runInShell: true);
        } else {
          await Process.start(
              'explorer.exe', [targetDirOrFile.replaceAll('/', r'\')],
              runInShell: true);
        }
      } else if (Platform.isMacOS) {
        if (type == FileSystemEntityType.file) {
          await Process.start('open', ['-R', filePath]);
        } else {
          await Process.start('open', [targetDirOrFile]);
        }
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [targetDirOrFile]);
      } else {
        BealibDialog.showToast(message: '此平台不支持通过此方法打开文件管理器');
      }
    } catch (e) {
      BealibDialog.showToast(message: '无法打开文件管理器');
      BealibLogger().w('Update: reveal in file manager failed', error: e);
    }
  }

  String _getFileNameFromUrl(String url, String version) {
    final uri = Uri.parse(url);
    final fileName = uri.pathSegments.last;

    if (fileName.isNotEmpty) {
      return fileName;
    }
    String extension = '';
    if (Platform.isWindows) {
      extension = '.msix';
    } else if (Platform.isMacOS) {
      extension = '.dmg';
    } else if (Platform.isLinux) {
      extension = '.deb';
    } else if (Platform.isAndroid) {
      extension = '.apk';
    }
    return 'Bealib-$version$extension';
  }
}
