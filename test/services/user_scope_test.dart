import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sirapro/services/api_service.dart';
import 'package:sirapro/services/offline_queue_service.dart';
import 'package:sirapro/services/user_scope.dart';

OfflineOperation _op(String label) => OfflineOperation.json(
      label: label,
      method: 'POST',
      path: '/api/orders',
      body: {'client_id': 1},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserScope.setUser(null);
    ApiService().clearToken();
  });

  group('UserScope', () {
    test('un commercial ne voit pas les saisies en attente d\'un autre', () async {
      final queue = OfflineQueueService();

      await UserScope.setUser(1);
      await queue.enqueue(_op('Commande — A'));

      await UserScope.setUser(2);
      expect(await queue.pendingOperations(), isEmpty);
      await queue.enqueue(_op('Commande — B'));

      await UserScope.setUser(1);
      final pending = await queue.pendingOperations();
      expect(pending.map((op) => op.label), ['Commande — A']);
    });

    test('les anciennes données globales passent au premier compte seulement',
        () async {
      SharedPreferences.setMockInitialValues({
        'offline_queue_v1': '[]',
        'local_orders_v1': '[{"x":1}]',
        'offline_cache_v1:GET:/api/clients': '{}',
      });

      await UserScope.setUser(7);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('u7/local_orders_v1'), '[{"x":1}]');
      expect(prefs.containsKey('local_orders_v1'), isFalse);
      expect(prefs.containsKey('offline_cache_v1:GET:/api/clients'), isFalse);

      await UserScope.setUser(8);
      expect(prefs.containsKey('u8/local_orders_v1'), isFalse);
    });

    test('sans session, le rejeu ne fait basculer aucune saisie en échec',
        () async {
      final queue = OfflineQueueService();
      await UserScope.setUser(1);
      await queue.enqueue(_op('Commande — A'));

      // Pas de token : rien ne doit partir.
      await queue.flush();

      expect(await queue.pendingOperations(), hasLength(1));
      expect(await queue.failedOperations(), isEmpty);
    });
  });

  group('OfflineQueueService.isAlreadyApplied', () {
    OfflineOperation terminate() => OfflineOperation.json(
          label: 'Fin de visite',
          method: 'POST',
          path: '/api/visits/12/terminate',
          body: {'status': 'completed'},
        );

    test('une fin de visite déjà terminée côté serveur compte comme envoyée', () {
      final e = ApiException(
          'Visit is already terminated. Current status: completed',
          statusCode: 422);
      expect(OfflineQueueService.isAlreadyApplied(terminate(), e), isTrue);
    });

    test('un refus de distance reste un vrai échec', () {
      final e = ApiException('Current distance: 450 meters', statusCode: 422);
      expect(OfflineQueueService.isAlreadyApplied(terminate(), e), isFalse);
    });

    test('les autres saisies ne sont pas concernées', () {
      final e = ApiException('Current status: completed', statusCode: 422);
      expect(OfflineQueueService.isAlreadyApplied(_op('Commande'), e), isFalse);
    });
  });
}
