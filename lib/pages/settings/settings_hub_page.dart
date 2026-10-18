import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:bealib/request/config/api_endpoints.dart';
import 'package:bealib/utils/theme.dart';

/// 设置页（底部导航第二个 Tab）。
///
/// 严格按《应用需求.md》组织：
/// 设置 / 下载番剧 / 规则设置（增添规则）/ 播放设置 /
/// 下载设置（自定义下载目录、设置下载集数）/ 网络设置 / 更新设置 / 关于。
class SettingsHubPage extends StatelessWidget {
  const SettingsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme text = theme.textTheme;
    final double topInset = MediaQuery.viewPaddingOf(context).top;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        BealibTokens.pagePadding,
        topInset + 14,
        BealibTokens.pagePadding,
        210,
      ),
      children: [
        Text(
          '设置',
          style: text.displayLarge?.copyWith(color: scheme.onSurface),
        ),
        const SizedBox(height: 2),
        Text(
          '内容、播放与系统偏好',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 22),

        // 下载番剧
        const _SettingsGroup(
          tiles: [
            _SettingsTileData(
              icon: Icons.download_rounded,
              label: '下载番剧',
              description: '查看与管理已下载的剧集',
              route: '/download/',
            ),
          ],
        ),

        // 规则设置：仓库规则默认全部安装，只保留「增添规则」（导入 / 自己写）
        const _SettingsGroup(
          title: '规则设置',
          tiles: [
            _SettingsTileData(
              icon: Icons.add_link_rounded,
              label: '增添规则',
              description: '导入规则或自己编写，仓库规则默认全部安装',
              route: '/settings/plugin/add',
            ),
          ],
        ),

        // 播放设置 / 下载设置 / 网络设置 / 更新设置 / 关于
        const _SettingsGroup(
          tiles: [
            _SettingsTileData(
              icon: Icons.display_settings_rounded,
              label: '播放设置',
              description: '解码、渲染、弹幕与操作',
              route: '/settings/player',
            ),
            _SettingsTileData(
              icon: Icons.folder_rounded,
              label: '下载设置',
              description: '自定义下载目录与下载集数',
              route: '/settings/download-settings',
            ),
            _SettingsTileData(
              icon: Icons.language_rounded,
              label: '网络设置',
              description: '访问加速与代理',
              route: '/settings/proxy',
            ),
            _SettingsTileData(
              icon: Icons.update_rounded,
              label: '更新设置',
              description: '检查并安装最新版本',
              route: '/settings/update',
            ),
            _SettingsTileData(
              icon: Icons.info_outline_rounded,
              label: '关于',
              description: '软件介绍与第三方许可',
              route: '/settings/about',
            ),
          ],
        ),

        const SizedBox(height: 28),
        Center(
          child: Text(
            ApiEndpoints.version,
            style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _SettingsTileData {
  const _SettingsTileData({
    required this.icon,
    required this.label,
    required this.description,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String description;
  final String route;
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({this.title, required this.tiles});

  final String? title;
  final List<_SettingsTileData> tiles;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                title!,
                style: text.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Material(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(BealibTokens.cardRadius),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int i = 0; i < tiles.length; i++) ...[
                  _SettingsTile(data: tiles[i]),
                  if (i != tiles.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 72),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: scheme.outlineVariant,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.data});

  final _SettingsTileData data;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${data.label}，${data.description}',
      child: InkWell(
        onTap: () => context.pushNamed(data.route),
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(data.icon, size: 22, color: scheme.onSurface),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.label,
                      style: text.titleSmall?.copyWith(color: scheme.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
