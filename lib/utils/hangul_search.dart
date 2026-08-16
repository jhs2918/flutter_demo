// [B] 한글 초성 검색을 지원하기 위한 유틸리티.
const List<String> _choseongList = <String>[
  'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ',
  'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
];

const int _hangulBase = 0xAC00;
const int _hangulLast = 0xD7A3;
const int _choseongCount = 21 * 28;

/// 완성형 한글 음절의 초성만 뽑아 문자열로 만든다. 한글 음절이 아닌 문자는 그대로 둔다.
String choseongOf(String text) {
  final StringBuffer buffer = StringBuffer();
  for (final int rune in text.runes) {
    if (rune >= _hangulBase && rune <= _hangulLast) {
      final int index = (rune - _hangulBase) ~/ _choseongCount;
      buffer.write(_choseongList[index]);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// 검색어가 초성으로만 이루어져 있는지(예: "ㅂㅎ") 확인한다.
bool isChoseongOnly(String text) {
  if (text.isEmpty) return false;
  return text.runes
      .every((int r) => _choseongList.contains(String.fromCharCode(r)));
}

/// [B] 단어가 검색어와 일치하는지 확인한다. 검색어가 초성으로만 이루어져 있으면
/// 초성 검색을, 아니면 일반 텍스트 부분일치 검색을 한다.
bool matchesSearchQuery(String label, String query) {
  final String trimmed = query.trim();
  if (trimmed.isEmpty) return false;
  if (isChoseongOnly(trimmed)) {
    return choseongOf(label).contains(trimmed);
  }
  return label.toLowerCase().contains(trimmed.toLowerCase());
}
