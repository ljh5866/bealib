/// 轻量 HTML 文本解码。
///
/// Bangumi 镜像接口返回的标题/简介里可能带 HTML 实体（如 `&amp;`），
/// 直接渲染会把 `&amp;` 原样显示。这里只做纯文本解码，不解析标签，
/// 避免引入 HTML 渲染依赖（符合「仅显示番剧元数据」的需求边界）。
String decodeHtmlEntities(String input) {
  if (input.isEmpty || !input.contains('&')) return input;
  var text = input
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ');
  // 数值实体：&#123; 与 &#x1F600;
  text = text.replaceAllMapped(RegExp(r'&#(x[0-9a-fA-F]+|\d+);'), (match) {
    final String value = match.group(1)!;
    final int? codePoint = value.startsWith('x')
        ? int.tryParse(value.substring(1), radix: 16)
        : int.tryParse(value);
    if (codePoint == null) return match.group(0)!;
    return String.fromCharCode(codePoint);
  });
  return text;
}
