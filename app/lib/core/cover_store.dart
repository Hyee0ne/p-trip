import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 사진첩에서 고른 여행기 대표 사진의 보관함 (2026-09-09).
///
/// 시스템 사진 선택기(PHPicker)는 권한 없이 뜨고, 사진 식별자 대신 **복사본**을 준다.
/// 그 복사본을 앱 문서 폴더 `covers/` 에 두고 여행기엔 파일 이름만 적는다.
/// ⚠ 절대경로를 저장하지 않는다 — iOS 는 앱을 업데이트하면 Documents 경로가 바뀐다.
/// ⚠ 원본을 그대로 두지 않는다. 선택기에서 1600px · 85% 로 줄여 받는다 — 썸네일과 카드면 충분하다.
class CoverStore {
  CoverStore._();

  static String? _root;

  /// 앱 시작 때 한 번. 이걸 안 부르면 [fileFor] 가 null 을 돌려준다.
  static Future<void> init() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/covers');
      if (!await dir.exists()) await dir.create(recursive: true);
      _root = dir.path;
    } catch (_) {
      // 문서 폴더를 못 열면 사진첩 대표는 이번 실행에 안 된다. 앱은 돈다.
    }
  }

  /// 저장된 이름 → 파일. 폴더를 모르거나 이름이 비면 null.
  static File? fileFor(String name) {
    final root = _root;
    if (root == null || name.isEmpty) return null;
    return File('$root/$name');
  }

  /// 사진 선택기를 띄우고, 고른 사진을 복사해 이름을 돌려준다. 안 골랐으면 null.
  static Future<String?> pick(String tripId, {String? replacing}) async {
    final root = _root;
    if (root == null) return null;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (picked == null) return null;
    final name = '$tripId-${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(picked.path).copy('$root/$name');
    // 전에 고른 파일은 지운다 — 같은 여행기에 둘이 남을 이유가 없다.
    if (replacing != null && replacing.isNotEmpty) {
      try {
        await File('$root/$replacing').delete();
      } catch (_) {
        /* 이미 없으면 그만 */
      }
    }
    return name;
  }
}
