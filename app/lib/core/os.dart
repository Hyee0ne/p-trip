import 'dart:io';

/// `Platform.operatingSystemVersion` — iOS 는 "Version 26.6 (Build 23G80)" 꼴이다. 못 읽으면 0.
int osMajorVersion(String raw) {
  final m = RegExp(r'(\d+)\.').firstMatch(raw);
  return m == null ? 0 : int.parse(m.group(1)!);
}

/// 지금 도는 iOS 의 큰 버전. iOS 가 아니면(테스트) 0.
int get iosMajor => Platform.isIOS ? osMajorVersion(Platform.operatingSystemVersion) : 0;
