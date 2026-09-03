import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_card_combination.dart';

/// [낱말카드 개편] 이름 붙여 저장한 카드 선택 + AI 결과 목록을 휴대폰
/// 저장공간의 "케어노트" 폴더 안 파일(saved_combinations.json)에 보관한다
/// - 예전에는 SharedPreferences(앱 내부에 숨겨진 저장소)에만 저장했는데,
/// 파일 관리 앱에서 실제로 찾아볼 수 있는 폴더가 있어야 한다는 요청으로
/// 바꿨다. 안드로이드는 앱 전용 외부 저장공간(별도 권한 필요 없음), 그 외
/// 플랫폼은 문서 폴더 아래에 만든다. 이 파일 안 내용은 이 앱이 다시
/// 불러올 때 쓰는 내부 형식 그대로라 사람이 보기 좋은 문서는 아니다.
class SavedCardCombinationRepository {
  static const String _fileName = 'saved_combinations.json';
  // 예전 버전에서 쓰던 SharedPreferences 키 - 딱 한 번, 파일이 아직
  // 없을 때만 읽어서 파일로 옮겨준다(기존 사용자 데이터 보존).
  static const String _legacyPrefsKey = 'saved_card_combinations';

  Future<Directory> _careNoteDirectory() async {
    final Directory base = Platform.isAndroid
        ? (await getExternalStorageDirectory() ??
              await getApplicationDocumentsDirectory())
        : await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${base.path}/케어노트');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _file() async {
    final Directory dir = await _careNoteDirectory();
    return File('${dir.path}/$_fileName');
  }

  List<SavedCardCombination> _decode(String raw) {
    if (raw.isEmpty) return <SavedCardCombination>[];
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (dynamic item) =>
                SavedCardCombination.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on Object {
      // 저장된 내용이 손상된 경우 앱이 아예 못 뜨는 것보다 빈 목록으로 시작하는 편이 낫다.
      return <SavedCardCombination>[];
    }
  }

  Future<List<SavedCardCombination>> load() async {
    // [방어 처리] 저장소 폴더/파일 접근 자체가 실패해도(권한 문제, 저장
    // 공간 없음 등) 화면이 로딩 스피너에 멈춰버리는 것보다 빈 목록으로
    // 시작하는 편이 낫다.
    try {
      final File file = await _file();
      if (await file.exists()) {
        return _decode(await file.readAsString());
      }

      // [마이그레이션] 파일이 아직 없으면 예전 SharedPreferences 데이터가
      // 있는지 한 번 확인해서, 있으면 파일로 옮겨준다.
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? legacyRaw = prefs.getString(_legacyPrefsKey);
      if (legacyRaw == null || legacyRaw.isEmpty) {
        return <SavedCardCombination>[];
      }
      final List<SavedCardCombination> legacy = _decode(legacyRaw);
      if (legacy.isNotEmpty) {
        await save(legacy);
        await prefs.remove(_legacyPrefsKey);
      }
      return legacy;
    } on Object {
      return <SavedCardCombination>[];
    }
  }

  Future<void> save(List<SavedCardCombination> combinations) async {
    final File file = await _file();
    await file.writeAsString(
      jsonEncode(
        combinations.map((SavedCardCombination c) => c.toJson()).toList(),
      ),
    );
  }
}
