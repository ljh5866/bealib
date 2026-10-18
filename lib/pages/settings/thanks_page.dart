import 'package:flutter/material.dart';

import 'package:bealib/bean/settings/settings_detail_scaffold.dart';
import 'package:bealib/pages/settings/thanks_entries.dart';
import 'package:bealib/utils/theme.dart';

/// 致谢页：每行「名称————说明」。
class ThanksPage extends StatelessWidget {
  const ThanksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme text = theme.textTheme;

    return SettingsDetailScaffold(
      title: const Text('致谢'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          BealibTokens.pagePadding,
          12,
          BealibTokens.pagePadding,
          32,
        ),
        children: [
          if (bealibThanksEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  '暂无致谢内容',
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(BealibTokens.cardRadius),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < bealibThanksEntries.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: SelectableText(
                        bealibThanksEntries[i].display,
                        style: text.bodyLarge?.copyWith(
                          color: scheme.onSurface,
                          height: 1.6,
                        ),
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
