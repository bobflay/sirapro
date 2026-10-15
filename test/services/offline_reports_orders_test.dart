import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sirapro/services/api_service.dart';
import 'package:sirapro/services/daily_report_service.dart';
import 'package:sirapro/services/local_order_service.dart';
import 'package:sirapro/services/offline_cache_service.dart';
import 'package:sirapro/services/order_service.dart';

/// Réseau coupé : toute requête échoue comme sans connexion.
final offline = MockClient((_) async => throw http.ClientException('offline'));

Map<String, dynamic> order(int id, int clientId) => {
      'id': id,
      'reference': 'CMD-$id',
      'client_id': clientId,
      'status': 'pending',
      'total_amount': 1000,
      'created_at': '2026-10-1${id % 10}T10:00:00Z',
    };

LocalOrder localOrder({required String status, String ref = 'order_local_1'}) =>
    LocalOrder(
      providesRef: ref,
      reference: 'HL-1',
      clientId: 5,
      clientName: 'Bob Test Client 2',
      createdAt: DateTime.now(),
      totalAmount: 2000,
      items: [
        LocalOrderItem(
          productId: 1,
          productName: 'BISCUIT',
          quantity: 1,
          saleType: 'pack',
          unitPrice: 2000,
          lineTotal: 2000,
          status: status,
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService().setToken('token');
  });

  group('listOrders hors ligne', () {
    test('liste d\'un client jamais consultée : retrouvée dans la liste '
        'générale en cache', () async {
      await OfflineCacheService().put('GET:/api/orders?page=1&per_page=20', {
        'status': true,
        'data': {
          'current_page': 1,
          'last_page': 1,
          'total': 3,
          'per_page': 20,
          'data': [order(1, 5), order(2, 9), order(3, 5)],
        },
      });

      final response = await http.runWithClient(
        () => OrderService().listOrders(clientId: 5),
        () => offline,
      );

      expect(response.orders.map((o) => o.id), [3, 1]);
    });

    test('rien en cache pour ce client : erreur réseau conservée', () async {
      await expectLater(
        http.runWithClient(
          () => OrderService().listOrders(clientId: 5),
          () => offline,
        ),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('rapport journalier', () {
    Future<void> cacheServerReport() {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      return OfflineCacheService().put('GET:/api/daily-report?date=$today', {
        'success': true,
        'data': {
          'orders': {
            'commande_non_facturee': {'count': 1, 'total': 500},
            'commande_facturee': {'count': 2, 'total': 7000},
          },
        },
      });
    }

    Future<dynamic> report() => http.runWithClient(
          () => DailyReportService().getDailyReport(),
          () => offline,
        );

    test('commande hors ligne non livrée : ajoutée aux non facturées',
        () async {
      await cacheServerReport();
      await LocalOrderService().add(localOrder(status: 'pending'));

      final orders = (await report()).orders;

      expect(orders.commandeNonFacturee.count, 2);
      expect(orders.commandeNonFacturee.total, 2500);
      expect(orders.commandeFacturee.count, 2);
    });

    test('commande hors ligne livrée : ajoutée aux facturées', () async {
      await cacheServerReport();
      await LocalOrderService().add(localOrder(status: 'delivered'));

      final orders = (await report()).orders;

      expect(orders.commandeFacturee.count, 3);
      expect(orders.commandeFacturee.total, 9000);
      expect(orders.commandeNonFacturee.count, 1);
    });
  });
}
