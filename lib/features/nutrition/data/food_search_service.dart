import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

/// Kết quả tra cứu món ăn (từ bảng VN hoặc Open Food Facts).
class FoodSearchResult {
  final String name;
  final String? brand;
  final double kcal100; // trên 100g
  final double protein100;
  final double carbs100;
  final double fat100;
  final String source; // 'VN' (Viện Dinh Dưỡng) | 'OFF' (Open Food Facts)
  final String? barcode;

  const FoodSearchResult({
    required this.name,
    this.brand,
    required this.kcal100,
    required this.protein100,
    required this.carbs100,
    required this.fat100,
    required this.source,
    this.barcode,
  });

  /// Quy đổi theo khối lượng thực tế.
  FoodSearchResult portion(double grams) => FoodSearchResult(
        name: name,
        brand: brand,
        kcal100: kcal100 * grams / 100,
        protein100: protein100 * grams / 100,
        carbs100: carbs100 * grams / 100,
        fat100: fat100 * grams / 100,
        source: source,
        barcode: barcode,
      );
}

/// Tra cứu món ăn:
/// 1. Bảng Thành phần Thực phẩm VN (Viện Dinh Dưỡng) — offline, nhúng sẵn asset.
/// 2. Open Food Facts — API mở, online (tìm theo tên / barcode).
class FoodSearchService {
  FoodSearchService._();
  static final instance = FoodSearchService._();

  static const _offHeaders = {
    'User-Agent': 'GTBrain-Health-App/1.0 (Vietnam)',
  };

  List<FoodSearchResult>? _vnFoods;

  /// Nạp bảng VN từ asset (gọi 1 lần, cache).
  Future<List<FoodSearchResult>> loadVnFoods() async {
    if (_vnFoods != null) return _vnFoods!;
    try {
      final raw = await rootBundle.loadString('assets/data/vn_foods.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _vnFoods = (data['foods'] as List)
          .map((e) => FoodSearchResult(
                name: (e['name'] as String).trim(),
                kcal100: (e['kcal'] as num).toDouble(),
                protein100: (e['p'] as num?)?.toDouble() ?? 0,
                carbs100: (e['c'] as num?)?.toDouble() ?? 0,
                fat100: (e['f'] as num?)?.toDouble() ?? 0,
                source: 'VN',
              ))
          .toList();
    } catch (_) {
      _vnFoods = [];
    }
    return _vnFoods!;
  }

  /// Tìm không dấu/có dấu kiểu loose-match tiếng Việt.
  List<FoodSearchResult> searchVn(String query, {int limit = 12}) {
    final q = _normalize(query);
    if (q.isEmpty) {
      return const [];
    }
    final all = _vnFoods ?? const <FoodSearchResult>[];
    return all
        .where((f) => _normalize(f.name).contains(q))
        .take(limit)
        .toList();
  }

  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
      .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
      .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
      .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
      .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
      .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
      .replaceAll('đ', 'd')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Tìm trên Open Food Facts theo tên (online).
  Future<List<FoodSearchResult>> searchOff(String query,
      {int limit = 12}) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    try {
      final uri = Uri.https('world.openfoodfacts.org', '/cgi/search.pl', {
        'search_terms': q,
        'search_simple': '1',
        'action': 'process',
        'json': '1',
        'page_size': '$limit',
        'fields': 'code,product_name,brands,nutriments',
      });
      final res = await http
          .get(uri, headers: _offHeaders)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const [];
      final data = jsonDecode(utf8.decode(res.bodyBytes))
          as Map<String, dynamic>;
      final products = (data['products'] as List? ?? []);
      return products
          .map(_fromOffProduct)
          .whereType<FoodSearchResult>()
          .take(limit)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Tra barcode trên Open Food Facts.
  Future<FoodSearchResult?> lookupBarcode(String barcode) async {
    try {
      final uri = Uri.https('world.openfoodfacts.org',
          '/api/v2/product/$barcode.json', {
        'fields': 'code,product_name,brands,nutriments',
      });
      final res = await http
          .get(uri, headers: _offHeaders)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(res.bodyBytes))
          as Map<String, dynamic>;
      if (data['status'] != 1) return null;
      return _fromOffProduct(data['product']);
    } catch (_) {
      return null;
    }
  }

  FoodSearchResult? _fromOffProduct(dynamic raw) {
    if (raw is! Map) return null;
    final name = (raw['product_name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    final nutriments = raw['nutriments'];
    if (nutriments is! Map) return null;

    double? readKcal() {
      final v = nutriments['energy-kcal_100g'] ?? nutriments['energy-kcal'];
      final n = v is num ? v.toDouble() : double.tryParse('$v');
      if (n != null) return n;
      // fallback: energy kJ → kcal
      final kj = nutriments['energy_100g'];
      final kjn = kj is num ? kj.toDouble() : double.tryParse('$kj');
      return kjn == null ? null : kjn / 4.184;
    }

    double readNum(String key) {
      final v = nutriments[key];
      return v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
    }

    final kcal = readKcal();
    if (kcal == null || kcal <= 0) return null;

    final brands = (raw['brands'] as String?)?.trim();
    return FoodSearchResult(
      name: name,
      brand: brands == null || brands.isEmpty ? null : brands.split(',')[0],
      kcal100: kcal,
      protein100: readNum('proteins_100g'),
      carbs100: readNum('carbohydrates_100g'),
      fat100: readNum('fat_100g'),
      source: 'OFF',
      barcode: raw['code'] as String?,
    );
  }
}
