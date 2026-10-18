/// 致谢名单（文本自行编辑）。
///
/// 每一行显示为「名称————说明」。
/// 直接改下面的列表即可：name 写人名/项目名，description 写感谢说明。
class ThanksEntry {
  const ThanksEntry({required this.name, required this.description});

  final String name;
  final String description;

  String get display => '$name————$description';
}

/// TODO: 把 xxx 换成你要感谢的人或项目。
const List<ThanksEntry> bealibThanksEntries = <ThanksEntry>[
  ThanksEntry(name: 'xxx', description: 'xxx'),
  ThanksEntry(name: 'xxx', description: 'xxx'),
  ThanksEntry(name: 'xxx', description: 'xxx'),
];
