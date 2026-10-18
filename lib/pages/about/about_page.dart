import 'package:flutter/material.dart';

import 'package:bealib/bean/settings/settings_detail_scaffold.dart';
import 'package:bealib/bean/widget/content_section.dart';
import 'package:bealib/bean/widget/tonal_card.dart';
import 'package:bealib/pages/about/about_intro.dart';
import 'package:bealib/pages/about/about_widgets.dart';

/// 关于页：只展示「软件介绍」与「第三方许可」。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final intro = bealibAboutIntro.trim();

    return SettingsDetailScaffold(
      title: const Text('关于'),
      body: AboutContent(
        children: [
          Text(
            '软件介绍',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TonalCard(
            padding: const EdgeInsets.all(16),
            child: intro.isEmpty
                ? Text(
                    '软件介绍暂未填写。',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  )
                : Text(
                    intro,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
          ),
          const SizedBox(height: 24),
          ContentSection.group(
            title: '第三方许可',
            children: const [
              AboutLinkTile.route(
                icon: Icons.description_outlined,
                title: '查看第三方许可',
                route: '/settings/about/license',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
