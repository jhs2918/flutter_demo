import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/card_catalog.dart';

/// [낱말카드 개편] assets/data/cards_visit.json + cards_day.json을 읽어
/// [CardCatalog]로 파싱한다. 정적 데이터라 한 번 읽으면 프로세스 내내
/// 바뀌지 않으므로, 화면에 다시 들어올 때마다 에셋을 또 읽고 파싱하지
/// 않도록 결과를 캐시해둔다.
class CardCatalogRepository {
  static const String _visitAssetPath = 'assets/data/cards_visit.json';
  static const String _dayAssetPath = 'assets/data/cards_day.json';
  static CardCatalog? _cached;

  Future<CardCatalog> load() async {
    final CardCatalog? cached = _cached;
    if (cached != null) return cached;

    final List<String> raw = await Future.wait(<Future<String>>[
      rootBundle.loadString(_visitAssetPath),
      rootBundle.loadString(_dayAssetPath),
    ]);
    final CardCatalog catalog = CardCatalog.fromParts(
      visitJson: jsonDecode(raw[0]) as List<dynamic>,
      dayJson: jsonDecode(raw[1]) as List<dynamic>,
    );
    _cached = catalog;
    return catalog;
  }
}
