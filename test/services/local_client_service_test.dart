import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sirapro/models/client.dart';
import 'package:sirapro/services/local_client_service.dart';

void main() {
  group('LocalClientService', () {
    late LocalClientService service;

    Client buildClient(int id) {
      final now = DateTime(2026, 8, 27);
      return Client(
        id: id,
        name: 'Boutique Awa',
        type: 'Mamie marché',
        managerName: 'Awa',
        phones: const ['+22500000000'],
        city: 'Abidjan',
        address: 'Marché de Cocody',
        latitude: 5.35,
        longitude: -4.02,
        hasOpenAlert: false,
        createdAt: now,
        updatedAt: now,
      );
    }

    Future<void> addLocalClient({
      String ref = 'client_1735000000000',
      int id = -1735000000000,
    }) async {
      await service.add(LocalClient(
        providesRef: ref,
        client: buildClient(id),
        createdAt: DateTime(2026, 8, 27),
      ));
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = LocalClientService();
    });

    /// Le PDV saisi hors ligne doit rester sous les yeux du commercial :
    /// c'est le seul endroit d'où il peut y démarrer une visite.
    test('a client created offline stays in the list', () async {
      await addLocalClient();

      final pending = await service.pendingClients();

      expect(pending, hasLength(1));
      expect(pending.first.name, 'Boutique Awa');
      expect(pending.first.id, isNegative);
    });

    test('the full fiche survives a round-trip through storage', () async {
      await addLocalClient();

      final client = (await service.pendingClients()).first;

      expect(client.type, 'Mamie marché');
      expect(client.managerName, 'Awa');
      expect(client.phones, ['+22500000000']);
      expect(client.city, 'Abidjan');
      expect(client.latitude, 5.35);
    });

    /// Une fois la création rejouée, la version serveur prend le relais dans
    /// la liste : garder la copie locale afficherait le PDV en double.
    test('the local copy disappears once the creation is synced', () async {
      await addLocalClient();
      SharedPreferences.setMockInitialValues({
        'local_clients_v1': jsonEncode([
          {
            'provides_ref': 'client_1735000000000',
            'client': buildClient(-1735000000000).toJson(),
            'created_at': '2026-08-27T00:00:00.000',
          }
        ]),
        'offline_queue_refs_v1': jsonEncode({'client_1735000000000': '4242'}),
      });

      expect(await service.pendingClients(), isEmpty);
      expect(await service.syncedServerId(-1735000000000), 4242);
    });

    /// Un écran encore ouvert sur l'ancienne fiche doit continuer à désigner
    /// le bon client une fois la copie locale retirée de la liste.
    test('the local id still resolves after the copy is dropped', () async {
      SharedPreferences.setMockInitialValues({
        'local_clients_v1': jsonEncode([
          {
            'provides_ref': 'client_1735000000000',
            'client': buildClient(-1735000000000).toJson(),
            'created_at': '2026-08-27T00:00:00.000',
          }
        ]),
        'offline_queue_refs_v1': jsonEncode({'client_1735000000000': '4242'}),
      });

      // La liste purge la fiche locale…
      await service.pendingClients();

      // …mais l'écran ouvert dessus retrouve toujours l'id serveur.
      expect(await service.syncedServerId(-1735000000000), 4242);
      expect(await service.queueReferenceFor(-1735000000000), '4242');
    });

    group('queueReferenceFor()', () {
      test('leaves a server id untouched', () async {
        expect(await service.queueReferenceFor(42), '42');
      });

      /// La visite et les photos saisies sur ce PDV doivent le désigner par
      /// sa référence : la file y substituera l'id serveur après la création.
      test('designates a pending client by its queue reference', () async {
        await addLocalClient();

        expect(await service.queueReferenceFor(-1735000000000),
            '{ref:client_1735000000000}');
      });

      test('uses the server id as soon as the reference resolves', () async {
        SharedPreferences.setMockInitialValues({
          'local_clients_v1': jsonEncode([
            {
              'provides_ref': 'client_1735000000000',
              'client': buildClient(-1735000000000).toJson(),
              'created_at': '2026-08-27T00:00:00.000',
            }
          ]),
          'offline_queue_refs_v1': jsonEncode({'client_1735000000000': '4242'}),
        });

        expect(await service.queueReferenceFor(-1735000000000), '4242');
      });

      test('returns null for an unknown local id', () async {
        expect(await service.queueReferenceFor(-999), isNull);
      });
    });
  });
}
