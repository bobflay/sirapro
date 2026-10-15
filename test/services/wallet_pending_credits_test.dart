import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sirapro/services/offline_queue_service.dart';
import 'package:sirapro/services/wallet_service.dart';

OfflineOperation delivery({
  required int productId,
  required bool delivered,
  double amount = 12500,
  String order = 'HL-644932',
}) =>
    OfflineOperation.json(
      label: 'Livraison $order — BISCUIT',
      method: 'PUT',
      path: '/api/orders/{ref:order_local_1}/items/status-by-product',
      body: {
        'items': [
          {
            'product_id': productId,
            'status': delivered ? 'delivered' : 'not_delivered',
          },
        ],
      },
      meta: WalletService.deliveryMeta(
        orderReference: order,
        itemKey: 'product_$productId',
        productName: 'BISCUIT CLEO CREME X 100',
        amount: amount,
        delivered: delivered,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('une livraison en file apparaît comme crédit en attente', () async {
    await OfflineQueueService().enqueue(delivery(productId: 1, delivered: true));

    final credits = await WalletService().pendingDeliveryCredits();

    expect(credits, hasLength(1));
    final credit = credits.single;
    expect(credit.isCredit, isTrue);
    expect(credit.amount, 12500);
    expect(credit.isPending, isTrue);
    expect(credit.pendingReference, 'HL-644932');
    expect(credit.description, 'Livraison — BISCUIT CLEO CREME X 100');
  });

  test('livré puis non livré : aucun crédit', () async {
    final queue = OfflineQueueService();
    await queue.enqueue(delivery(productId: 1, delivered: true));
    await queue.enqueue(delivery(productId: 1, delivered: false));

    expect(await WalletService().pendingDeliveryCredits(), isEmpty);
  });

  test('les autres saisies en file ne créent pas de transaction', () async {
    await OfflineQueueService().enqueue(OfflineOperation.json(
      label: 'Commande HL-644932 — Bob',
      method: 'POST',
      path: '/api/orders',
      body: {'client_id': 1},
    ));

    expect(await WalletService().pendingDeliveryCredits(), isEmpty);
  });

  test('la métadonnée survit à la persistance de la file', () async {
    final op = delivery(productId: 2, delivered: true, amount: 3000);
    final restored = OfflineOperation.fromJson(op.toJson());
    expect(restored.meta, op.meta);
    expect(restored.withBlocked('x').meta, op.meta);
  });
}
