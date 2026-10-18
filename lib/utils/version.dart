import 'dart:math';

bool needUpdate(String localVersion, String remoteVersion) {
  final localVersionList = localVersion.split('.');
  final remoteVersionList = remoteVersion.split('.');
  final maxLength = max(localVersionList.length, remoteVersionList.length);
  for (var i = 0; i < maxLength; i++) {
    final localSegment = i < localVersionList.length
        ? _parseSegment(localVersionList[i])
        : 0;
    final remoteSegment = i < remoteVersionList.length
        ? _parseSegment(remoteVersionList[i])
        : 0;
    if (remoteSegment > localSegment) {
      return true;
    } else if (remoteSegment < localSegment) {
      return false;
    }
  }
  return false;
}

int _parseSegment(String piece) {
  // 兼容 v1.2.3 / 1.2.3-beta 之类的 tag。
  final digits = piece.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(digits) ?? 0;
}
