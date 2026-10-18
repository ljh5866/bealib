import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:bealib/bean/card/network_img_layer.dart';
import 'package:bealib/bean/widget/image_preview.dart';
import 'package:bealib/modules/bangumi/bangumi_item.dart';
import 'package:bealib/modules/bangumi/bangumi_relation.dart';
import 'package:bealib/modules/characters/character_item.dart';
import 'package:bealib/pages/info/widgets/bealib_info_header.dart';
import 'package:bealib/pages/video/video_playback_args.dart';
import 'package:bealib/request/apis/bangumi_api.dart';
import 'package:bealib/services/logging/logger.dart';
import 'package:bealib/utils/html_text.dart';
import 'package:bealib/utils/theme.dart';

/// 播放页「番剧信息」Tab：只放《应用需求.md》定义的信息模块——
/// 番剧名称（头部卡片）、简介、分类标签、角色与配音、关联番剧。
class BealibVideoInfoPanel extends StatefulWidget {
  const BealibVideoInfoPanel({
    super.key,
    required this.bangumiItem,
    required this.showRating,
  });

  final BangumiItem bangumiItem;
  final bool showRating;

  @override
  State<BealibVideoInfoPanel> createState() => _BealibVideoInfoPanelState();
}

class _BealibVideoInfoPanelState extends State<BealibVideoInfoPanel> {
  late BangumiItem _item = widget.bangumiItem;

  bool _infoLoading = false;
  bool _charactersLoading = true;
  bool _relationsLoading = true;

  List<CharacterItem> _characters = <CharacterItem>[];
  List<BangumiRelation> _relations = <BangumiRelation>[];

  bool _fullIntro = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait(<Future<void>>[
      _loadInfo(),
      _loadCharacters(),
      _loadRelations(),
    ]);
  }

  Future<void> _loadInfo() async {
    if (_item.summary.trim().isNotEmpty && _item.tags.isNotEmpty) return;
    setState(() => _infoLoading = true);
    try {
      final BangumiItem? info = await BangumiApi.getBangumiInfoByID(_item.id);
      if (!mounted || info == null) return;
      setState(() => _item = info);
    } catch (error) {
      BealibLogger()
          .w('BealibVideoInfoPanel: load info failed', error: error);
    } finally {
      if (mounted) setState(() => _infoLoading = false);
    }
  }

  Future<void> _loadCharacters() async {
    try {
      final response = await BangumiApi.getCharatersByBangumiID(_item.id);
      if (!mounted) return;
      setState(() => _characters = response.charactersList);
    } catch (error) {
      BealibLogger()
          .w('BealibVideoInfoPanel: load characters failed', error: error);
    } finally {
      if (mounted) setState(() => _charactersLoading = false);
    }
  }

  Future<void> _loadRelations() async {
    // 镜像偶发超时：失败后自动重试一次。
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final relations = await BangumiApi.getBangumiRelationsByID(_item.id);
        if (!mounted) return;
        setState(() {
          _relations = relations;
          _relationsLoading = false;
        });
        return;
      } catch (error) {
        BealibLogger().w(
          'BealibVideoInfoPanel: load relations failed (attempt ${attempt + 1})',
          error: error,
        );
      }
    }
    if (mounted) setState(() => _relationsLoading = false);
  }

  void _openRelated(BangumiItem item) {
    context.pushNamed(
      '/video/',
      arguments: PendingOnlinePlaybackArgs(bangumiItem: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          BealibInfoHeader(
            bangumiItem: _item,
            showRating: widget.showRating,
            isLoading: _infoLoading,
          ),
          _buildSectionCard(
            context,
            title: '简介',
            child: _buildSummary(context),
          ),
          _buildSectionCard(
            context,
            title: '分类标签',
            child: _buildTags(context),
          ),
          _buildSectionCard(
            context,
            title: '角色与配音',
            trailing: _characters.isEmpty ? null : '${_characters.length} 位',
            child: _buildCharacters(context),
          ),
          _buildSectionCard(
            context,
            title: '关联番剧',
            trailing: _relations.isEmpty ? null : '${_relations.length} 部',
            child: _buildRelations(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    String? trailing,
    required Widget child,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(BealibTokens.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: text.titleMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (trailing != null)
                Text(
                  trailing,
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String summary = decodeHtmlEntities(_item.summary).trim();
    if (_infoLoading && summary.isEmpty) {
      return _skeleton(context, 4);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          summary.isEmpty ? '暂无简介' : summary,
          maxLines: _fullIntro ? 100 : 5,
          overflow: TextOverflow.ellipsis,
          style: text.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.6,
          ),
        ),
        if (summary.length > 120)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _fullIntro = !_fullIntro),
              child: Text(_fullIntro ? '收起' : '展开'),
            ),
          ),
      ],
    );
  }

  Widget _buildTags(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final tags = _item.tags
        .map((tag) => tag.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (tags.isEmpty) {
      return Text(
        '暂无标签',
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final String tag in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Text(
              tag,
              style:
                  text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  Widget _buildCharacters(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    if (_charactersLoading) return _skeleton(context, 2);
    if (_characters.isEmpty) {
      return Text(
        '暂无角色信息',
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      );
    }
    final List<String> avatars = <String>[
      for (final CharacterItem character in _characters)
        if (_characterAvatarUrl(character).isNotEmpty)
          _characterAvatarUrl(character),
    ];
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _characters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final CharacterItem character = _characters[index];
          final String avatar = _characterAvatarUrl(character);
          return _CharacterCard(
            character: character,
            onImageTap: avatar.isEmpty
                ? null
                : () => ImageViewer.show(
                      context,
                      imageUrls: avatars,
                      initialIndex: avatars.indexOf(avatar),
                    ),
          );
        },
      ),
    );
  }

  Widget _buildRelations(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    if (_relationsLoading) return _skeleton(context, 2);
    if (_relations.isEmpty) {
      return Text(
        '暂无关联番剧',
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      );
    }
    return SizedBox(
      height: 186,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _relations.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final relation = _relations[index];
          return _RelationCard(
            relation: relation,
            onTap: () => _openRelated(relation.bangumiItem),
          );
        },
      ),
    );
  }

  Widget _skeleton(BuildContext context, int lines) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < lines; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FractionallySizedBox(
              widthFactor: i == lines - 1 ? 0.5 : 1,
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _characterAvatarUrl(CharacterItem character) {
  final CharacterAvator avator = character.avator;
  for (final String url in [avator.large, avator.medium, avator.grid]) {
    if (url.isNotEmpty) return url;
  }
  return '';
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.character, this.onImageTap});

  final CharacterItem character;
  final VoidCallback? onImageTap;

  String get _name {
    final String cn = character.info.nameCn.trim();
    if (cn.isNotEmpty) return cn;
    return character.name.trim();
  }

  String get _cv {
    final names = character.actorList
        .map((actor) => actor.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    return names.isEmpty ? '' : 'CV：${names.join(' / ')}';
  }

  String get _avatar => _characterAvatarUrl(character);

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return SizedBox(
      width: 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_avatar.isEmpty)
            Container(
              width: 92,
              height: 112,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
            )
          else
            Semantics(
              button: true,
              label: '查看 $_name 图片',
              child: GestureDetector(
                onTap: onImageTap,
                child: NetworkImgLayer(
                  src: _avatar,
                  width: 92,
                  height: 112,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            _name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelMedium?.copyWith(color: scheme.onSurface),
          ),
          if (_cv.isNotEmpty)
            Text(
              _cv,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _RelationCard extends StatelessWidget {
  const _RelationCard({required this.relation, required this.onTap});

  final BangumiRelation relation;
  final VoidCallback onTap;

  String get _title {
    final String cn = relation.bangumiItem.nameCn.trim();
    if (cn.isNotEmpty) return cn;
    return relation.bangumiItem.name.trim();
  }

  String get _cover {
    final Map<String, String> images = relation.bangumiItem.images;
    for (final String key in const ['large', 'common', 'medium']) {
      final String url = images[key] ?? '';
      if (url.isNotEmpty) return url;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${relation.relation} $_title',
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 104,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cover.isEmpty
                    ? Container(
                        width: 104,
                        height: 116,
                        color: scheme.surfaceContainer,
                      )
                    : NetworkImgLayer(
                        src: _cover,
                        width: 104,
                        height: 116,
                        fit: BoxFit.cover,
                      ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          relation.relation,
                          style:
                              text.labelSmall?.copyWith(color: scheme.onSurface),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            text.labelSmall?.copyWith(color: scheme.onSurface),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
