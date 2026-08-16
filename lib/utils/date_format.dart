/// 날짜/시간을 "YYYY.MM.DD HH:mm" 형태로 포맷한다. 별도 패키지 없이 직접 구현한다.
String formatDateTime(DateTime dateTime) {
  final DateTime local = dateTime.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}.${two(local.month)}.${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
