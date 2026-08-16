import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/card_catalog.dart';

/// [낱말카드 개편] assets/data/cards.json을 읽어 [CardCatalog]로 파싱한다.
/// 정적 데이터라 한 번 읽으면 프로세스 내내 바뀌지 않으므로, 화면에 다시
/// 들어올 때마다 에셋을 또 읽고 파싱하지 않도록 결과를 캐시해둔다.
class CardCatalogRepository {
  static const String _assetPath = 'assets/data/cards.json';
  static CardCatalog? _cached;

  Future<CardCatalog> load() async {
    final CardCatalog? cached = _cached;
    if (cached != null) return cached;

    final String raw = await rootBundle.loadString(_assetPath);
    final Map<String, dynamic> decoded =
        jsonDecode(raw) as Map<String, dynamic>;
    final CardCatalog catalog = CardCatalog.fromJson(decoded);
    _cached = catalog;
    return catalog;
  }
}
