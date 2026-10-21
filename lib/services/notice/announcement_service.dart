import 'dart:async';

import 'package:bealib/bean/dialog/announcement_dialog.dart';
import 'package:bealib/bean/dialog/dialog_helper.dart';
import 'package:bealib/bean/notice/announcement.dart';
import 'package:bealib/services/logging/logger.dart';
import 'package:bealib/services/storage/storage.dart';

/// 公告：启动时按公告 id 自动弹一次，设置页可随时查看。
class AnnouncementService {
  const AnnouncementService();

  static bool _showing = false;

  /// 启动时调用：同一公告 id 只自动弹一次；有其它弹窗（如强制更新）时稍后再弹。
  Future<void> maybeShow() async {
    if (_showing) return;
    final String seen = GStorage.getSetting(SettingsKeys.announcementSeenId);
    if (seen == bealibAnnouncement.id) return;

    _showing = true;
    try {
      for (var attempt = 0; attempt < 8; attempt++) {
        if (!BealibDialog.observer.hasBealibDialog) break;
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
      await showDialog(markSeen: true);
    } catch (e) {
      BealibLogger().w('Announcement: failed to show announcement', error: e);
    } finally {
      _showing = false;
    }
  }

  /// 显示公告弹窗；[markSeen] 为 true 时标记该公告已读。
  Future<void> showDialog({bool markSeen = false}) async {
    if (BealibDialog.observer.hasBealibDialog) return;
    await BealibDialog.show<void>(
      clickMaskDismiss: false,
      builder: (context) =>
          AnnouncementDialog(announcement: bealibAnnouncement),
    );
    if (markSeen) {
      await GStorage.putSetting(
        SettingsKeys.announcementSeenId,
        bealibAnnouncement.id,
      );
    }
  }

  /// 设置页「公告」页内展示时使用，不弹窗。
  BealibAnnouncement get announcement => bealibAnnouncement;
}
