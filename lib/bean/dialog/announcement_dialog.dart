import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bealib/bean/dialog/dialog_helper.dart';
import 'package:bealib/bean/notice/announcement.dart';
import 'package:bealib/request/config/api_endpoints.dart';

/// 公告弹窗：标题 + 日期 + 正文 + 「访问官网 / 我知道了」。
class AnnouncementDialog extends StatelessWidget {
  const AnnouncementDialog({super.key, required this.announcement});

  final BealibAnnouncement announcement;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme text = theme.textTheme;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: Row(
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
                  announcement.title,
                  style: text.titleLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  announcement.updatedAt,
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.55,
          maxWidth: 440,
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            announcement.content,
            style: text.bodyMedium?.copyWith(
              color: scheme.onSurface,
              height: 1.7,
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
          onPressed: () => BealibDialog.dismiss(context: context),
          child: const Text('我知道了'),
        ),
      ],
    );
  }
}
