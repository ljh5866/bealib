/// 公告内容（文本自行编辑）。
///
/// - 修改 [content] 即更换公告正文；
/// - 修改 [id] 后，即使用户看过旧公告也会再次弹出（每个 id 只自动弹一次）。
const BealibAnnouncement bealibAnnouncement = BealibAnnouncement(
  id: '2026-10-22',
  title: '公告',
  updatedAt: '2026-10-22',
  content: '''
因为一些原因决定暂停维护此项目，但项目趋于稳定，可通过邮箱联系2442852575@qq.com。''',
);

class BealibAnnouncement {
  const BealibAnnouncement({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.content,
  });

  /// 公告版本标识；内容大改时换成新 id 即可让用户重新看到。
  final String id;

  final String title;

  /// 日期文本，例如 2026-10-22。
  final String updatedAt;

  /// 公告正文（纯文本，换行会保留）。
  final String content;
}
