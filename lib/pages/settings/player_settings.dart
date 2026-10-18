import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:bealib/bean/dialog/dialog_helper.dart';
import 'package:bealib/bean/settings/settings_detail_scaffold.dart';
import 'package:bealib/bean/settings/settings_dropdown_tile.dart';
import 'package:bealib/pages/player/controller/player_aspect_ratio.dart';
import 'package:bealib/pages/settings/low_memory_mode_settings.dart';
import 'package:bealib/utils/constants.dart';
import 'package:bealib/services/storage/storage.dart';
import 'package:bealib/services/player/pip_utils.dart';
import 'package:bealib/bean/settings/settings_list.dart';
import 'package:bealib/utils/device.dart';

class PlayerSettingsPage extends StatefulWidget {
  const PlayerSettingsPage({super.key});

  @override
  State<PlayerSettingsPage> createState() => _PlayerSettingsPageState();
}

class _PlayerSettingsPageState extends State<PlayerSettingsPage> {
  static const double _minPlayerControllerLayerDisappearSeconds = 1;
  static const double _maxPlayerControllerLayerDisappearSeconds = 10;
  static const int _playerControllerLayerDisappearDivisions = 18;

  late double defaultPlaySpeed;
  late double defaultShortcutForwardPlaySpeed;
  late PlayerAspectRatio defaultAspectRatioMode;
  late bool hAenable;
  late bool androidEnableOpenSLES;
  late bool androidAutoEnterPIP;
  late bool playResume;
  late bool privateMode;
  late bool playerDisableAnimations;
  late bool forceAdBlocker;
  late bool autoPlayNext;
  late bool autoSelectFastestRule;
  late bool backgroundPlayback;
  late bool brightnessVolumeGesture;
  late int playerButtonSkipTime;
  late int playerArrowKeySkipTime;
  late int playerControllerLayerDisappearTime;

  @override
  void initState() {
    super.initState();
    _loadSettingsFromStorage();
  }

  void _loadSettingsFromStorage() {
    defaultPlaySpeed =
        GStorage.getSetting<double>(SettingsKeys.defaultPlaySpeed);
    defaultShortcutForwardPlaySpeed = GStorage.getSetting<double>(
        SettingsKeys.defaultShortcutForwardPlaySpeed);
    defaultAspectRatioMode = PlayerAspectRatio.fromStorageValue(
      GStorage.getSetting<int>(SettingsKeys.defaultAspectRatioType),
    );
    hAenable = GStorage.getSetting<bool>(SettingsKeys.hAenable);
    androidEnableOpenSLES =
        GStorage.getSetting<bool>(SettingsKeys.androidEnableOpenSLES);
    androidAutoEnterPIP =
        GStorage.getSetting<bool>(SettingsKeys.androidAutoEnterPIP);
    playResume = GStorage.getSetting<bool>(SettingsKeys.playResume);
    privateMode = GStorage.getSetting<bool>(SettingsKeys.privateMode);
    autoPlayNext = GStorage.getSetting<bool>(SettingsKeys.autoPlayNext);
    autoSelectFastestRule =
        GStorage.getSetting<bool>(SettingsKeys.autoSelectFastestRule);
    backgroundPlayback =
        GStorage.getSetting<bool>(SettingsKeys.backgroundPlayback);
    playerDisableAnimations =
        GStorage.getSetting<bool>(SettingsKeys.playerDisableAnimations);
    forceAdBlocker = GStorage.getSetting<bool>(SettingsKeys.forceAdBlocker);

    brightnessVolumeGesture =
        GStorage.getSetting<bool>(SettingsKeys.brightnessVolumeGesture);

    playerButtonSkipTime =
        GStorage.getSetting<int>(SettingsKeys.buttonSkipTime);
    playerArrowKeySkipTime =
        GStorage.getSetting<int>(SettingsKeys.arrowKeySkipTime);

    playerControllerLayerDisappearTime = GStorage.getSetting<int>(
        SettingsKeys.playerControllerLayerDisappearTime);
  }

  Future<void> resetPlayerSettings() async {
    final bool shouldReset = await BealibDialog.show<bool>(
          builder: (context) => AlertDialog(
            title: const Text('恢复默认播放设置'),
            content: const Text('播放设置、硬件解码器、视频渲染器和超分辨率设置将恢复为默认值。'),
            actions: [
              TextButton(
                onPressed: () => BealibDialog.dismiss(popWith: false),
                child: Text('取消'),
              ),
              TextButton(
                onPressed: () => BealibDialog.dismiss(popWith: true),
                child: Text('恢复默认'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldReset) return;

    await GStorage.resetPlayerSettings();
    if (Platform.isAndroid) {
      await PipUtils.setAndroidAutoEnterPIPEnabled(false);
    }
    if (!mounted) return;
    setState(_loadSettingsFromStorage);
    BealibDialog.showToast(message: '已恢复默认播放设置');
  }

  void updateDefaultPlaySpeed(double speed) {
    GStorage.putSetting<double>(SettingsKeys.defaultPlaySpeed, speed);
    setState(() {
      defaultPlaySpeed = speed;
    });
  }

  void updateDefaultShortcutForwardPlaySpeed(double speed) {
    GStorage.putSetting<double>(
        SettingsKeys.defaultShortcutForwardPlaySpeed, speed);
    setState(() {
      defaultShortcutForwardPlaySpeed = speed;
    });
  }

  void updateDefaultAspectRatioMode(PlayerAspectRatio mode) {
    GStorage.putSetting<int>(
      SettingsKeys.defaultAspectRatioType,
      mode.storageValue,
    );
    setState(() {
      defaultAspectRatioMode = mode;
    });
  }

  Future<void> updateButtonSkipTime() async {
    final int? newButtonSkipTime = await _showSkipTimeChangeDialog(
        title: '顶部按钮快进时长', initialValue: playerButtonSkipTime.toString());

    if (newButtonSkipTime != null &&
        newButtonSkipTime != playerButtonSkipTime) {
      GStorage.putSetting<int>(SettingsKeys.buttonSkipTime, newButtonSkipTime);
      setState(() {
        playerButtonSkipTime = newButtonSkipTime;
      });
    }
  }

  Future<int?> _showSkipTimeChangeDialog(
      {required String title, required String initialValue}) async {
    return BealibDialog.show<int>(builder: (context) {
      String input = "";
      return AlertDialog(
        title: Text(title),
        content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return TextField(
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              floatingLabelBehavior: FloatingLabelBehavior.never,
              labelText: initialValue,
            ),
            onChanged: (value) {
              input = value;
            },
          );
        }),
        actions: <Widget>[
          TextButton(
            onPressed: () => BealibDialog.dismiss(),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () async {
              final int? newValue = int.tryParse(input);

              if (newValue == null) {
                BealibDialog.showToast(message: '请输入数字');
                return;
              }

              if (newValue <= 0) {
                BealibDialog.showToast(message: '请输入大于0的数字');
                return;
              }
              BealibDialog.dismiss(popWith: newValue);
            },
            child: const Text('确定'),
          ),
        ],
      );
    });
  }

  double get playerControllerLayerDisappearSeconds =>
      (playerControllerLayerDisappearTime / Duration.millisecondsPerSecond)
          .clamp(_minPlayerControllerLayerDisappearSeconds,
              _maxPlayerControllerLayerDisappearSeconds)
          .toDouble();

  String formatPlayerControllerLayerDisappearSeconds(double seconds) {
    if (seconds == seconds.roundToDouble()) {
      return '${seconds.toInt()} 秒';
    }
    return '${seconds.toStringAsFixed(1)} 秒';
  }

  void updatePlayerControllerLayerDisappearSeconds(double seconds) {
    final int newDisappearTime =
        (seconds * Duration.millisecondsPerSecond).round();
    if (newDisappearTime == playerControllerLayerDisappearTime) {
      return;
    }
    GStorage.putSetting<int>(
        SettingsKeys.playerControllerLayerDisappearTime, newDisappearTime);
    setState(() {
      playerControllerLayerDisappearTime = newDisappearTime;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsDetailScaffold(
      title: const Text('播放设置'),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text('解码与渲染'),
            tiles: [
              SettingsTile.switchTile(
                leading: Icons.memory_rounded,
                onToggle: (value) async {
                  hAenable = value ?? !hAenable;
                  await GStorage.putSetting<bool>(
                      SettingsKeys.hAenable, hAenable);
                  setState(() {});
                },
                title: Text('硬件解码'),
                initialValue: hAenable,
              ),
              SettingsTile(
                leading: Icons.developer_board_rounded,
                onPressed: (_) async {
                  await context.pushNamed('/settings/player/decoder');
                },
                title: Text('硬件解码器'),
                description: Text('仅在硬件解码启用时生效'),
              ),
              if (Platform.isAndroid) ...[
                SettingsTile(
                  leading: Icons.tv_rounded,
                  onPressed: (_) async {
                    await context.pushNamed('/settings/player/renderer');
                  },
                  title: Text('视频渲染器'),
                  description: Text('选择视频输出方式'),
                ),
              ],
              const LowMemoryModeSettingsTile(),
              if (Platform.isAndroid) ...[
                SettingsTile.switchTile(
                  leading: Icons.graphic_eq_rounded,
                  onToggle: (value) async {
                    androidEnableOpenSLES = value ?? !androidEnableOpenSLES;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.androidEnableOpenSLES,
                        androidEnableOpenSLES);
                    setState(() {});
                  },
                  title: Text('低延迟音频'),
                  description: Text('启用OpenSLES音频输出以降低延时'),
                  initialValue: androidEnableOpenSLES,
                ),
              ],
              SettingsTile(
                leading: Icons.auto_awesome_rounded,
                onPressed: (_) async {
                  context.pushNamed('/settings/player/super');
                },
                title: Text('超分辨率'),
              ),
            ],
          ),
          SettingsSection(
            title: Text('播放行为'),
            tiles: [
              SettingsTile.switchTile(
                leading: Icons.headphones_rounded,
                onToggle: (value) async {
                  backgroundPlayback = value ?? !backgroundPlayback;
                  await GStorage.putSetting<bool>(
                      SettingsKeys.backgroundPlayback, backgroundPlayback);
                  setState(() {});
                },
                title: Text('后台播放'),
                description: Text('应用退到后台或熄屏时继续播放音频'),
                initialValue: backgroundPlayback,
              ),
              SettingsTile.switchTile(
                leading: Icons.history_rounded,
                onToggle: (value) async {
                  playResume = value ?? !playResume;
                  await GStorage.putSetting<bool>(
                      SettingsKeys.playResume, playResume);
                  setState(() {});
                },
                title: Text('自动跳转'),
                description: Text('跳转到上次播放位置'),
                initialValue: playResume,
              ),
              SettingsTile.switchTile(
                leading: Icons.playlist_play_rounded,
                onToggle: (value) async {
                  autoPlayNext = value ?? !autoPlayNext;
                  await GStorage.putSetting<bool>(
                      SettingsKeys.autoPlayNext, autoPlayNext);
                  setState(() {});
                },
                title: Text('自动连播'),
                description: Text('当前视频播放完毕后自动播放下一集'),
                initialValue: autoPlayNext,
              ),
              SettingsTile.switchTile(
                leading: Icons.speed_rounded,
                onToggle: (value) async {
                  autoSelectFastestRule = value ?? !autoSelectFastestRule;
                  await GStorage.putSetting<bool>(
                      SettingsKeys.autoSelectFastestRule, autoSelectFastestRule);
                  setState(() {});
                },
                title: Text('自动选择最快规则'),
                description: Text('进入播放时自动使用检索最快的规则；播放失败不会自动切换'),
                initialValue: autoSelectFastestRule,
              ),
              if (Platform.isAndroid)
                SettingsTile.switchTile(
                  leading: Icons.picture_in_picture_alt_rounded,
                  onToggle: (value) async {
                    androidAutoEnterPIP = value ?? !androidAutoEnterPIP;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.androidAutoEnterPIP, androidAutoEnterPIP);
                    await PipUtils.setAndroidAutoEnterPIPEnabled(
                        androidAutoEnterPIP);
                    setState(() {});
                  },
                  title: Text('自动进入画中画'),
                  description: Text('切到后台时，自动进入画中画'),
                  initialValue: androidAutoEnterPIP,
                ),
              SettingsTile.switchTile(
                leading: Icons.block_rounded,
                onToggle: (value) async {
                  forceAdBlocker = value ?? !forceAdBlocker;
                  await GStorage.putSetting<bool>(
                      SettingsKeys.forceAdBlocker, forceAdBlocker);
                  setState(() {});
                },
                title: Text('广告过滤'),
                description: Text('强制启用HLS广告过滤，忽略规则设置'),
                initialValue: forceAdBlocker,
              ),
              SettingsTile.switchTile(
                leading: Icons.animation_rounded,
                onToggle: (value) async {
                  playerDisableAnimations = value ?? !playerDisableAnimations;
                  await GStorage.putSetting<bool>(
                      SettingsKeys.playerDisableAnimations,
                      playerDisableAnimations);
                  setState(() {});
                },
                title: Text('禁用动画'),
                description: Text('禁用播放器内的过渡动画'),
                initialValue: playerDisableAnimations,
              ),
              if (!isDesktop())
                SettingsTile.switchTile(
                  leading: Icons.swipe_vertical_rounded,
                  onToggle: (value) async {
                    brightnessVolumeGesture = value ?? !brightnessVolumeGesture;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.brightnessVolumeGesture,
                        brightnessVolumeGesture);
                    setState(() {});
                  },
                  title: Text('滑动手势'),
                  description: Text('竖向滑动调节音量和亮度'),
                  initialValue: brightnessVolumeGesture,
                ),
              SettingsTile.switchTile(
                leading: Icons.visibility_off_rounded,
                onToggle: (value) async {
                  privateMode = value ?? !privateMode;
                  await GStorage.putSetting<bool>(
                      SettingsKeys.privateMode, privateMode);
                  setState(() {});
                },
                title: Text('隐身模式'),
                description: Text('不保留观看记录'),
                initialValue: privateMode,
              ),
            ],
          ),
          SettingsSection(
            title: Text('播放参数'),
            tiles: [
              SettingsSliderTile(
                leading: Icons.speed_rounded,
                title: Text('默认倍速'),
                value: defaultPlaySpeed,
                min: 0.25,
                max: 3,
                divisions: 11,
                valueLabel: '${defaultPlaySpeed}x',
                onChanged: (value) => updateDefaultPlaySpeed(
                    double.parse(value.toStringAsFixed(2))),
              ),
              SettingsSliderTile(
                leading: Icons.fast_forward_rounded,
                title: Text('长按倍速'),
                description: Text('长按屏幕或按住方向键时的倍速'),
                value: defaultShortcutForwardPlaySpeed,
                min: 1.25,
                max: 3,
                divisions: 7,
                valueLabel: '${defaultShortcutForwardPlaySpeed}x',
                onChanged: (value) => updateDefaultShortcutForwardPlaySpeed(
                    double.parse(value.toStringAsFixed(2))),
              ),
              SettingsSliderTile(
                leading: Icons.swap_horiz_rounded,
                title: Text('方向键跳转'),
                description: Text('左右方向键的快进/快退秒数'),
                value: playerArrowKeySkipTime.toDouble(),
                min: 0,
                max: 15,
                divisions: 15,
                valueLabel: '$playerArrowKeySkipTime 秒',
                onChanged: (value) {
                  final newArrowKeySkipTime = value.toInt();
                  if (newArrowKeySkipTime == playerArrowKeySkipTime) {
                    return;
                  }
                  GStorage.putSetting<int>(
                      SettingsKeys.arrowKeySkipTime, newArrowKeySkipTime);
                  setState(() {
                    playerArrowKeySkipTime = newArrowKeySkipTime;
                  });
                },
              ),
              SettingsTile(
                leading: Icons.skip_next_rounded,
                onPressed: (_) async {
                  await updateButtonSkipTime();
                },
                title: Text('跳过时长'),
                description: Text('顶栏跳过按钮的秒数'),
                value: Text('$playerButtonSkipTime 秒'),
              ),
              SettingsSliderTile(
                leading: Icons.timer_rounded,
                title: Text('控制栏消失时间'),
                description: Text('播放控制器自动隐藏前的停留时长'),
                value: playerControllerLayerDisappearSeconds,
                min: _minPlayerControllerLayerDisappearSeconds,
                max: _maxPlayerControllerLayerDisappearSeconds,
                divisions: _playerControllerLayerDisappearDivisions,
                valueLabel: formatPlayerControllerLayerDisappearSeconds(
                    playerControllerLayerDisappearSeconds),
                onChanged: updatePlayerControllerLayerDisappearSeconds,
              ),
              SettingsDropdownTile<PlayerAspectRatio>(
                leading: Icons.aspect_ratio_rounded,
                title: const Text('默认视频比例'),
                value: defaultAspectRatioMode,
                options: {
                  for (final mode in PlayerAspectRatio.values) mode: mode.label,
                },
                onChanged: updateDefaultAspectRatioMode,
              ),
            ],
          ),
          SettingsSection(
            tiles: [
              SettingsTile(
                leading: Icons.settings_backup_restore_rounded,
                onPressed: (_) => resetPlayerSettings(),
                title: Text('恢复默认设置'),
                description: Text('将播放相关设置恢复为默认值'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
