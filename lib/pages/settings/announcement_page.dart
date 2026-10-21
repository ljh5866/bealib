import 'package:flutter/material.dart';

import 'package:bealib/bean/notice/announcement.dart';
import 'package:bealib/bean/settings/settings_detail_scaffold.dart';
import 'package:bealib/utils/theme.dart';

/// 公告页：设置里随时查看当前公告内容。
class AnnouncementPage extends StatelessWidget {
  const AnnouncementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme text = theme.textTheme;

    return SettingsDetailScaffold(
      title: const Text('公告'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          BealibTokens.pagePadding,
          12,
          BealibTokens.pagePadding,
          32,
        ),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(BealibTokens.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.campaign_rounded,
                        size: 22,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bealibAnnouncement.title,
                            style: text.titleMedium?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bealibAnnouncement.updatedAt,
                            style: text.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: scheme.outlineVariant),
                const SizedBox(height: 16),
                SelectableText(
                  bealibAnnouncement.content,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    height: 1.7,
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
