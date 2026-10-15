import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sirapro/services/api_service.dart';
import 'package:sirapro/services/offline_queue_service.dart';

/// Rejoue la file avec un faux serveur : [handler] reçoit chaque requête.
Future<void> flushWith(
    Future<http.Response> Function(http.Request request) handler) {
  return http.runWithClient(
    () => OfflineQueueService().flush(),
    () => MockClient(handler),
  );
}

http.Response json(int status, Object body) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

OfflineOperation startVisit({int clientId = 5}) => OfflineOperation(
      id: 'op_start',
      createdAt: DateTime.now(),
      label: 'Début de visite — MOHAMED',
      kind: 'json',
      method: 'POST',
      path: '/api/visits',
      body: {'client_id': clientId, 'latitude': 5.3, 'longitude': -4.0},
      provides: 'visit_-1',
    );

OfflineOperation terminateVisit(String visit) => OfflineOperation(
      id: 'op_end_$visit',
      createdAt: DateTime.now(),
      label: 'Fin de visite — MOHAMED',
      kind: 'json',
      method: 'POST',
      path: '/api/visits/$visit/terminate',
      body: {'status': 'completed', 'latitude': 5.3, 'longitude': -4.0},
    );

final unterminated = json(422, {
  'status': false,
  'message': 'You have an unterminated visit.',
  'errors': {
    'visit': ['Unterminated visit ID: 2068']
  },
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService().setToken('token');
  });

  group('isAlreadyApplied', () {
    test('une fin de visite déjà terminée compte comme synchronisée', () {
      final op = terminateVisit('12');
      expect(
        OfflineQueueService.isAlreadyApplied(
            op, ApiException('Current status: completed', statusCode: 422)),
        isTrue,
      );
    });

    test('un refus de distance reste un vrai échec', () {
      final op = terminateVisit('12');
      expect(
        OfflineQueueService.isAlreadyApplied(op,
            ApiException('The distance exceed reason field is required.',
                statusCode: 422)),
        isFalse,
      );
    });

    test('les autres saisies ne sont pas concernées', () {
      expect(
        OfflineQueueService.isAlreadyApplied(startVisit(),
            ApiException('Current status: completed', statusCode: 422)),
        isFalse,
      );
    });
  });

  group('openVisitIdFrom', () {
    test('lit l\'id de la visite restée ouverte', () {
      expect(
        OfflineQueueService.openVisitIdFrom(startVisit(),
            ApiException('Unterminated visit ID: 2068', statusCode: 422)),
        2068,
      );
    });

    test('ignore les autres opérations et les erreurs réseau', () {
      expect(
        OfflineQueueService.openVisitIdFrom(terminateVisit('12'),
            ApiException('Unterminated visit ID: 2068', statusCode: 422)),
        isNull,
      );
      expect(
        OfflineQueueService.openVisitIdFrom(
            startVisit(), ApiException('Unterminated visit ID: 2068')),
        isNull,
      );
    });
  });

  group('flush', () {
    test('fin de visite rejouée sur une visite déjà terminée : retirée', () async {
      final queue = OfflineQueueService();
      await queue.enqueue(terminateVisit('12'));

      await flushWith((_) async => json(422, {
            'status': false,
            'message': 'This visit is already terminated',
            'errors': {
              'status': ['Current status: completed']
            },
          }));

      expect(await queue.pendingOperations(), isEmpty);
      expect(await queue.failedOperations(), isEmpty);
    });

    test('début de visite déjà reçu (réponse perdue) : la visite ouverte est '
        'reprise et la fin de visite part sur elle', () async {
      final queue = OfflineQueueService();
      await queue.enqueue(startVisit());
      await queue.enqueue(terminateVisit('{ref:visit_-1}'));

      final calls = <String>[];
      await flushWith((request) async {
        calls.add('${request.method} ${request.url.path}');
        switch (request.url.path) {
          case '/api/visits':
            return unterminated;
          case '/api/visits/active':
            return json(200, {
              'data': {
                'id': 2068,
                'client_id': 5,
                'started_at': DateTime.now()
                    .subtract(const Duration(minutes: 3))
                    .toIso8601String(),
                'client': {'id': 5, 'name': 'MOHAMED'},
              },
            });
          default:
            return json(200, {'data': {'id': 2068}});
        }
      });

      expect(calls, contains('POST /api/visits/2068/terminate'));
      expect(await queue.pendingOperations(), isEmpty);
      expect(await queue.failedOperations(), isEmpty);
      expect(await queue.resolvedRef('visit_-1'), '2068');
    });

    test('visite ouverte chez un autre client : échec explicite, la suite '
        'reste bloquée', () async {
      final queue = OfflineQueueService();
      await queue.enqueue(startVisit());
      await queue.enqueue(terminateVisit('{ref:visit_-1}'));

      await flushWith((request) async {
        if (request.url.path == '/api/visits') return unterminated;
        return json(200, {
          'data': {
            'id': 2068,
            'client_id': 9,
            'started_at': DateTime.now().toIso8601String(),
            'client': {'id': 9, 'name': 'ALI'},
          },
        });
      });

      final failed = await queue.failedOperations();
      expect(failed, hasLength(1));
      expect(failed.single.error, contains('Visite n° 2068 chez ALI'));
      final pending = await queue.pendingOperations();
      expect(pending, hasLength(1));
      expect(pending.single.isBlocked, isTrue);
    });
  });

  group('session expirée', () {
    test('sans token (agent déconnecté) : rien n\'est envoyé', () async {
      ApiService().clearToken();
      final queue = OfflineQueueService();
      await queue.enqueue(startVisit());

      var calls = 0;
      await flushWith((_) async {
        calls++;
        return json(401, {'message': 'Unauthenticated.'});
      });

      expect(calls, 0);
      expect(await queue.pendingOperations(), hasLength(1));
      expect(await queue.failedOperations(), isEmpty);
    });

    test('401 : les saisies restent en file, sans échec ni blocage', () async {
      final queue = OfflineQueueService();
      await queue.enqueue(startVisit());
      await queue.enqueue(terminateVisit('{ref:visit_-1}'));

      await flushWith((_) async => json(401, {'message': 'Unauthenticated.'}));

      final pending = await queue.pendingOperations();
      expect(pending.map((op) => op.id), ['op_start', 'op_end_{ref:visit_-1}']);
      expect(pending.any((op) => op.isBlocked), isFalse);
      expect(await queue.failedOperations(), isEmpty);
    });

    test('échecs « Unauthenticated » d\'une version antérieure : remis en file '
        'et envoyés à la reconnexion', () async {
      final start = startVisit();
      final end = terminateVisit('{ref:visit_-1}')
          .withBlocked('Unauthenticated.');
      SharedPreferences.setMockInitialValues({
        'offline_queue_v1': jsonEncode([end.toJson()]),
        'offline_queue_failed_v1':
            jsonEncode([start.withError('Unauthenticated.').toJson()]),
        'offline_queue_blocked_refs_v1':
            jsonEncode({'visit_-1': 'Unauthenticated.'}),
      });
      final queue = OfflineQueueService();

      final sent = <String>[];
      await flushWith((request) async {
        sent.add(request.url.path);
        if (request.url.path == '/api/visits') {
          return json(201, {
            'data': {'id': 77}
          });
        }
        return json(200, {'status': true});
      });

      expect(sent, ['/api/visits', '/api/visits/77/terminate']);
      expect(await queue.pendingOperations(), isEmpty);
      expect(await queue.failedOperations(), isEmpty);
    });
  });

  group('commande refusée pour stock insuffisant', () {
    const stockError = 'Stock insuffisant pour ADJA SUPER DORE 240 X 12G : '
        '4 en stock, 11 demandé(s). Rechargez le stock.';

    OfflineOperation order() => OfflineOperation(
          id: 'op_order',
          createdAt: DateTime(2026, 10, 14, 9),
          label: 'Commande HL-948464 — BOUTIQUE',
          kind: 'json',
          method: 'POST',
          path: '/api/orders',
          body: {
            'client_id': 5,
            'items': [
              {'product_id': 1, 'quantity': 11, 'sale_type': 'pack', 'unit_price': 1000},
              {'product_id': 2, 'quantity': 3, 'sale_type': 'pack', 'unit_price': 500},
            ],
          },
          provides: 'order_local_1',
        );

    OfflineOperation delivery(int productId, double amount) => OfflineOperation(
          id: 'op_delivery_$productId',
          createdAt: DateTime(2026, 10, 14, 9, productId),
          label: 'Livraison HL-948464 — produit $productId',
          kind: 'json',
          method: 'PUT',
          path: '/api/orders/{ref:order_local_1}/items/status-by-product',
          body: {
            'items': [
              {'product_id': productId, 'status': 'delivered'},
            ],
          },
          meta: {
            'wallet_delivery': {
              'order': 'HL-948464',
              'item': 'product_$productId',
              'product': 'produit $productId',
              'amount': amount,
              'delivered': true,
            },
          },
        ).withBlocked(stockError);

    test('quantités corrigées : la commande repart, ses livraisons suivent '
        'et celle d\'un article retiré est abandonnée', () async {
      SharedPreferences.setMockInitialValues({
        'offline_queue_v1': jsonEncode([
          delivery(1, 11000).toJson(),
          delivery(2, 1500).toJson(),
        ]),
        'offline_queue_failed_v1':
            jsonEncode([order().withError(stockError).toJson()]),
        'offline_queue_blocked_refs_v1':
            jsonEncode({'order_local_1': stockError}),
      });
      final queue = OfflineQueueService();

      // Sans session, le rejeu attend : on inspecte la file corrigée.
      ApiService().clearToken();
      await queue.retryFailedOrder('op_order', {'1|pack': 4, '2|pack': 0});

      final pending = await queue.pendingOperations();
      expect(pending.map((op) => op.id), ['op_order', 'op_delivery_1']);
      expect(pending.first.body!['items'], [
        {'product_id': 1, 'quantity': 4, 'sale_type': 'pack', 'unit_price': 1000},
      ]);
      expect(pending.last.isBlocked, isFalse);
      expect(pending.last.meta!['wallet_delivery']['amount'], 4000);
      expect(await queue.failedOperations(), isEmpty);

      ApiService().setToken('token');
      final sent = <String>[];
      await flushWith((request) async {
        sent.add(request.url.path);
        if (request.url.path == '/api/orders') {
          return json(201, {
            'data': {'id': 900}
          });
        }
        return json(200, {'status': true});
      });

      expect(sent, ['/api/orders', '/api/orders/900/items/status-by-product']);
      expect(await queue.pendingOperations(), isEmpty);
    });

    test('supprimer la commande emporte ses livraisons, pas le reste',
        () async {
      final other = terminateVisit('12');
      SharedPreferences.setMockInitialValues({
        'offline_queue_v1': jsonEncode([
          delivery(1, 11000).toJson(),
          other.toJson(),
          delivery(2, 1500).toJson(),
        ]),
        'offline_queue_failed_v1':
            jsonEncode([order().withError(stockError).toJson()]),
        'offline_queue_blocked_refs_v1':
            jsonEncode({'order_local_1': stockError}),
      });
      final queue = OfflineQueueService();
      final failed = (await queue.failedOperations()).single;

      expect((await queue.dependentsOf(failed)).map((op) => op.id),
          ['op_delivery_1', 'op_delivery_2']);

      final refs = await queue.discardFailed('op_order');

      expect(refs, {'order_local_1'});
      expect((await queue.pendingOperations()).map((op) => op.id), [other.id]);
      expect(await queue.failedOperations(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('offline_queue_blocked_refs_v1'), '{}');
    });

    test('supprimer un début de visite emporte en cascade la commande et ses '
        'livraisons', () async {
      final visitOrder = OfflineOperation.fromJson(order().toJson()
        ..['id'] = 'op_visit_order'
        ..['body'] = {...order().body!, 'visit_id': '{ref:visit_-1}'});
      SharedPreferences.setMockInitialValues({
        'offline_queue_v1': jsonEncode([
          visitOrder.toJson(),
          delivery(1, 11000).toJson(),
        ]),
        'offline_queue_failed_v1':
            jsonEncode([startVisit().withError('Refus').toJson()]),
      });
      final queue = OfflineQueueService();

      final refs = await queue.discardFailed('op_start');

      expect(refs, {'visit_-1', 'order_local_1'});
      expect(await queue.pendingOperations(), isEmpty);
    });

    test('tout retirer est refusé : la commande reste en échec', () async {
      SharedPreferences.setMockInitialValues({
        'offline_queue_failed_v1':
            jsonEncode([order().withError(stockError).toJson()]),
      });
      final queue = OfflineQueueService();

      await expectLater(
        queue.retryFailedOrder('op_order', {'1|pack': 0, '2|pack': 0}),
        throwsArgumentError,
      );
      expect(await queue.failedOperations(), hasLength(1));
    });
  });

  group('opération orpheline', () {
    test('création disparue (supprimée par une version antérieure) : '
        'signalée, jamais envoyée, supprimable', () async {
      final queue = OfflineQueueService();
      await queue.enqueue(terminateVisit('{ref:visit_-1}'));

      var calls = 0;
      await flushWith((_) async {
        calls++;
        return json(200, {'status': true});
      });

      expect(calls, 0);
      expect(await queue.orphanedIds(), {'op_end_{ref:visit_-1}'});
      expect((await queue.pendingOperations()).single.blockedReason,
          OfflineQueueService.orphanReason);

      await queue.discardOrphaned('op_end_{ref:visit_-1}');
      expect(await queue.pendingOperations(), isEmpty);
    });

    test('création encore en file : pas orpheline, pas supprimable', () async {
      final queue = OfflineQueueService();
      await queue.enqueue(startVisit());
      await queue.enqueue(terminateVisit('{ref:visit_-1}'));

      expect(await queue.orphanedIds(), isEmpty);
      expect(await queue.discardOrphaned('op_end_{ref:visit_-1}'), isEmpty);
      expect(await queue.pendingOperations(), hasLength(2));
    });

    test('création en échec : bloquée par son refus, pas orpheline', () async {
      final queue = OfflineQueueService();
      await queue.enqueue(startVisit());
      await queue.enqueue(terminateVisit('{ref:visit_-1}'));

      await flushWith((_) async =>
          json(422, {'status': false, 'message': 'Client inactif'}));

      expect(await queue.failedOperations(), hasLength(1));
      expect(await queue.orphanedIds(), isEmpty);
      expect((await queue.pendingOperations()).single.blockedReason,
          contains('Client inactif'));
    });
  });
}
