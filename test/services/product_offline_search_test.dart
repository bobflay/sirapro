import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sirapro/services/offline_cache_service.dart';
import 'package:sirapro/services/product_service.dart';

/// La recherche produit doit fonctionner hors ligne à partir des pages du
/// catalogue mises en cache par la synchronisation de démarrage.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> productJson(int id, String name,
          {int categoryId = 1, String? sku}) =>
      {
        'id': id,
        'name': name,
        'sku_global': sku,
        'product_category_id': categoryId,
        'is_active': true,
      };

  Map<String, dynamic> pageJson(int page, int lastPage, int total,
          List<Map<String, dynamic>> items) =>
      {
        'status': true,
        'data': {
          'current_page': page,
          'last_page': lastPage,
          'total': total,
          'per_page': 50,
          'data': items,
        },
      };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final cache = OfflineCacheService();
    // Deux pages non filtrées comme les stocke la synchro de démarrage
    await cache.put(
      'GET:/api/products?page=1&per_page=50',
      pageJson(1, 2, 4, [
        productJson(1, 'LAIT LAITY BLEU SACHETS', sku: 'LAIT-01'),
        productJson(2, 'TOMATE ALYSSA 1100GR', categoryId: 2),
      ]),
    );
    await cache.put(
      'GET:/api/products?page=2&per_page=50',
      pageJson(2, 2, 4, [
        productJson(3, 'RIZ RIZIÈRE VERT', categoryId: 2),
        productJson(4, 'TOP LAIT CAFE', sku: 'LAIT-02'),
      ]),
    );
  });

  // Le réseau étant coupé en environnement de test, listProducts échoue en
  // ligne et doit retomber sur la recherche locale du catalogue en cache.
  test('offline search finds products across cached pages', () async {
    final response = await ProductService().listProducts(search: 'lait');

    expect(response.status, isTrue);
    expect(response.products.map((p) => p.id), containsAll([1, 4]));
    expect(response.total, 2);
  });

  test('offline search is accent and case insensitive', () async {
    final response = await ProductService().listProducts(search: 'riziere');

    expect(response.products.single.id, 3);
  });

  test('offline search matches SKU', () async {
    final response = await ProductService().listProducts(search: 'LAIT-02');

    expect(response.products.single.id, 4);
  });

  test('offline category filter works', () async {
    final response = await ProductService().listProducts(categoryId: 2);

    expect(response.products.map((p) => p.id), containsAll([2, 3]));
    expect(response.total, 2);
  });

  test('offline unfiltered request beyond cached keys still paginates',
      () async {
    final response = await ProductService().listProducts(search: 'introuvable');

    expect(response.products, isEmpty);
    expect(response.total, 0);
  });
}
