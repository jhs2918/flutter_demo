import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_demo/models/saved_card_combination.dart';
import 'package:flutter_demo/services/saved_card_combination_repository.dart';

// [저장을 파일로] "케어노트" 폴더 안 파일로 저장/불러오기가 실제로 되는지,
// 예전 SharedPreferences 데이터가 있으면 파일로 옮겨지는지 확인한다.
// 위젯 테스트(pump 기반)와 달리 이 파일은 일반 test()라 진짜 이벤트
// 루프에서 실행되므로 dart:io 파일 작업이 문제없이 끝난다.
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tempDir = Directory.systemTemp.createTempSync('care_note_repo_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  SavedCardCombination sample(String name) => SavedCardCombination(
    name: name,
    savedAt: DateTime(2026, 8, 23),
    selectedKeys: const <String>['catA::피부상태::건조함'],
    numericValues: const <String, String>{},
    opinion: '',
    results: const <SavedResultEntry>[
      SavedResultEntry(label: '', text: '건조하셔서 보습제를 도포하였으며, 이후 다소 편안해짐'),
    ],
  );

  test('처음 불러올 땐 빈 목록이다', () async {
    final repo = SavedCardCombinationRepository();
    expect(await repo.load(), isEmpty);
  });

  test('저장하면 케어노트 폴더 안에 파일이 생기고, 다시 불러오면 그대로 나온다', () async {
    final repo = SavedCardCombinationRepository();
    await repo.save(<SavedCardCombination>[sample('김할머니')]);

    final File file = File('${tempDir.path}/케어노트/saved_combinations.json');
    expect(await file.exists(), isTrue);

    final List<SavedCardCombination> loaded = await repo.load();
    expect(loaded, hasLength(1));
    expect(loaded.single.name, '김할머니');
    expect(loaded.single.results.single.text, sample('김할머니').results.single.text);
  });

  test('예전 SharedPreferences 데이터가 있으면 파일로 옮겨진다', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'saved_card_combinations': jsonEncode(<Map<String, dynamic>>[
        sample('이전데이터').toJson(),
      ]),
    });

    final repo = SavedCardCombinationRepository();
    final List<SavedCardCombination> loaded = await repo.load();
    expect(loaded, hasLength(1));
    expect(loaded.single.name, '이전데이터');

    // 옮겨진 뒤에는 파일에서 바로 읽혀야 한다.
    final File file = File('${tempDir.path}/케어노트/saved_combinations.json');
    expect(await file.exists(), isTrue);
  });
}
