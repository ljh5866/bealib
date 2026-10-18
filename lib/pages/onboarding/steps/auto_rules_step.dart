import 'dart:async';

import 'package:flutter/material.dart';

import 'package:bealib/pages/onboarding/onboarding_step_layout.dart';
import 'package:bealib/plugins/plugins_controller.dart';

/// 引导页「规则准备」：默认自动安装仓库里的全部规则，无需手动选择。
class AutoRulesStep extends StatefulWidget {
  const AutoRulesStep({super.key, required this.controller});

  final PluginsController controller;

  @override
  State<AutoRulesStep> createState() => _AutoRulesStepState();
}

class _AutoRulesStepState extends State<AutoRulesStep> {
  bool _busy = true;
  bool _failed = false;
  int _installed = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_install());
  }

  Future<void> _install() async {
    try {
      final installed = await widget.controller.ensureAllCatalogRulesInstalled();
      if (!mounted) return;
      setState(() {
        _installed = installed;
        _busy = false;
        _failed = widget.controller.pluginList.isEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final int count = widget.controller.pluginList.length;
    return OnboardingStepLayout(
      leading: const OnboardingStepIcon(
        icon: Icons.auto_awesome_rounded,
        shape: OnboardingIconShape.flower,
      ),
      title: '规则已默认就绪',
      subtitle: '全部社区规则会在启动时自动安装并保持更新，无需手动添加；也可以随时在设置里导入或自己编写规则。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                if (_busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    _failed
                        ? Icons.wifi_off_rounded
                        : Icons.check_circle_rounded,
                    size: 22,
                    color: _failed ? colors.error : colors.primary,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _busy
                        ? '正在安装全部规则…'
                        : _failed
                            ? '规则安装失败，可稍后在设置中重试（当前 $count 条）'
                            : _installed > 0
                                ? '已自动安装 $_installed 条规则，共 $count 条可用'
                                : '已就绪：$count 条规则',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
