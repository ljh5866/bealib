import 'package:bealib/modules/bangumi/bangumi_item.dart';
import 'package:bealib/modules/search/plugin_search_module.dart';

/// 在规则的搜索结果中挑选与 Bangumi 条目最匹配的一条。
///
/// 规则的搜索接口只返回 `name` + `src`，不同站点对同一部番的命名、排序差异很大，
/// 直接取第一条很容易拿到其它季度 / 剧场版 / 同名作品。这里做一次保守打分：
/// 名称相似度为主，年份、季度、剧场版/OVA 等特征做加减分，尽量选中「对版」的那条。
class SearchResultMatcher {
  const SearchResultMatcher._();

  static const double _specialPenalty = -28;
  static const double _seasonMismatchPenalty = -35;

  /// 返回匹配分数最高的一条；[items] 为空时返回 null。
  static SearchItem? pickBest(
    List<SearchItem> items, {
    required String keyword,
    BangumiItem? target,
  }) {
    if (items.isEmpty) return null;
    if (items.length == 1) return items.first;

    final Set<String> titles = <String>{keyword};
    if (target != null) {
      titles.add(target.nameCn);
      titles.add(target.name);
      titles.addAll(target.alias);
    }
    final Set<String> normalizedTitles = titles
        .map(normalizeTitle)
        .where((title) => title.length >= 2)
        .toSet();
    if (normalizedTitles.isEmpty) return items.first;

    final bool targetIsSpecial =
        normalizedTitles.any((title) => _containsSpecialWord(title));
    final int? targetYear = target == null ? null : _extractYear(target.airDate);
    final int? targetSeason = _extractSeason(target?.nameCn ?? '') ??
        _extractSeason(target?.name ?? '');

    SearchItem? best = items.first;
    double bestScore = _score(
      normalizeTitle(items.first.name),
      normalizedTitles: normalizedTitles,
      candidateName: items.first.name,
      targetIsSpecial: targetIsSpecial,
      targetYear: targetYear,
      targetSeason: targetSeason,
    );
    for (final SearchItem item in items.skip(1)) {
      final double score = _score(
        normalizeTitle(item.name),
        normalizedTitles: normalizedTitles,
        candidateName: item.name,
        targetIsSpecial: targetIsSpecial,
        targetYear: targetYear,
        targetSeason: targetSeason,
      );
      if (score > bestScore) {
        best = item;
        bestScore = score;
      }
    }
    return best;
  }

  static double _score(
    String normalizedCandidate, {
    required Set<String> normalizedTitles,
    required String candidateName,
    required bool targetIsSpecial,
    required int? targetYear,
    required int? targetSeason,
  }) {
    if (normalizedCandidate.isEmpty) return -1000;
    double best = -1000;
    for (final String title in normalizedTitles) {
      double score;
      if (normalizedCandidate == title) {
        score = 100;
      } else if (normalizedCandidate.contains(title)) {
        final int extra = normalizedCandidate.length - title.length;
        score = 72 - extra.clamp(0, 40) * 1.5;
      } else if (title.contains(normalizedCandidate)) {
        score = 55;
      } else {
        final double similarity =
            _bigramSimilarity(normalizedCandidate, title);
        if (similarity < 0.25) continue;
        score = similarity * 60;
      }

      // 季度：Bangumi 标题里带「第 X 季/期」，搜索结果也带时比较；搜到额外季度要扣分。
      final int? candidateSeason = _extractSeason(candidateName);
      if (targetSeason != null && candidateSeason != null) {
        score += candidateSeason == targetSeason ? 12 : _seasonMismatchPenalty;
      } else if (targetSeason == null && candidateSeason != null) {
        score -= 12;
      }

      // 年份：Bangumi 开播年份出现在搜索结果名里，加分；出现明显不同年份扣分。
      if (targetYear != null) {
        final int? candidateYear = _extractYear(candidateName);
        if (candidateYear != null) {
          score += candidateYear == targetYear ? 8 : _specialPenalty / 2;
        } else if (candidateName.contains('$targetYear')) {
          score += 6;
        }
      }

      // 剧场版 / OVA / 特别篇等：Bangumi 本身不是特殊篇时要避开。
      if (!targetIsSpecial && _containsSpecialWord(candidateName)) {
        score += _specialPenalty;
      }

      if (score > best) best = score;
    }
    return best;
  }

  /// 归一化：全角转半角、转小写、去掉空白与常见标点/分隔符。
  static String normalizeTitle(String value) {
    final StringBuffer buffer = StringBuffer();
    for (final int rune in value.runes) {
      int code = rune;
      // 全角 ASCII -> 半角
      if (code >= 0xFF01 && code <= 0xFF5E) {
        code -= 0xFEE0;
      } else if (code == 0x3000) {
        code = 0x20;
      }
      final String char = String.fromCharCode(code).toLowerCase();
      if (RegExp(r'[0-9a-z\u4e00-\u9fff\u3040-\u30ff]').hasMatch(char)) {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  static int? _extractYear(String value) {
    final RegExpMatch? match = RegExp(r'(19|20)\d{2}').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  static final RegExp _cnSeason = RegExp(r'第\s*([0-9一二三四五六七八九十]+)\s*[季期部]');
  static final RegExp _enSeason =
      RegExp(r'(?:season|s)\s*([0-9]+)', caseSensitive: false);
  static final RegExp _ordinalSeason =
      RegExp(r'([0-9]+)(?:st|nd|rd|th)\s+season', caseSensitive: false);

  static int? _extractSeason(String value) {
    final RegExpMatch? cn = _cnSeason.firstMatch(value);
    if (cn != null) {
      final String digits = cn.group(1)!;
      final int? asNumber = int.tryParse(digits);
      if (asNumber != null) return asNumber;
      return _chineseNumber(digits);
    }
    final RegExpMatch? ordinal = _ordinalSeason.firstMatch(value);
    if (ordinal != null) return int.tryParse(ordinal.group(1)!);
    final RegExpMatch? en = _enSeason.firstMatch(value);
    if (en != null) return int.tryParse(en.group(1)!);
    return null;
  }

  static int? _chineseNumber(String value) {
    const Map<String, int> map = <String, int>{
      '一': 1,
      '二': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
      '十': 10,
    };
    if (value.length == 1) return map[value];
    // 十一 ~ 十九
    if (value.length == 2 && value.startsWith('十')) {
      return 10 + (map[value.substring(1)] ?? 0);
    }
    // 二十 ~ 九十九
    if (value.length == 2 && value.endsWith('十')) {
      return (map[value.substring(0, 1)] ?? 0) * 10;
    }
    if (value.length == 3 && value[1] == '十') {
      final int tens = map[value.substring(0, 1)] ?? 0;
      return tens * 10 + (map[value.substring(2)] ?? 0);
    }
    return null;
  }

  static const List<String> _specialWords = <String>[
    '剧场版',
    '电影版',
    '电影',
    'movie',
    'ova',
    'oad',
    '特别篇',
    '特別篇',
    '番外',
    '总集篇',
    '合集',
    '短片',
    'sp',
  ];

  static bool _containsSpecialWord(String value) {
    final String lower = value.toLowerCase();
    for (final String word in _specialWords) {
      if (lower.contains(word)) return true;
    }
    return false;
  }

  static double _bigramSimilarity(String a, String b) {
    final Set<String> aGrams = _bigrams(a);
    final Set<String> bGrams = _bigrams(b);
    if (aGrams.isEmpty || bGrams.isEmpty) return 0;
    final int common = aGrams.intersection(bGrams).length;
    return (2 * common) / (aGrams.length + bGrams.length);
  }

  static Set<String> _bigrams(String value) {
    final Set<String> grams = <String>{};
    if (value.length < 2) return grams;
    for (int i = 0; i < value.length - 1; i++) {
      grams.add(value.substring(i, i + 2));
    }
    return grams;
  }
}
