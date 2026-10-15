import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sirapro/services/client_service.dart';
import 'package:sirapro/services/offline_cache_service.dart';
import 'package:sirapro/services/visit_api_service.dart';
import 'package:sirapro/services/wallet_service.dart';

http.Response json(int status, Object body) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

/// Exécute [body] avec un réseau coupé : toute requête échoue.
Future<T> offline<T>(Future<T> Function() body) => http.runWithClient(
      body,
      () => MockClient((_) async => throw http.ClientException('offline')),
    );

/// Exécute [body] avec un faux serveur qui répond [response] à tout.
Future<T> online<T>(Future<T> Function() body, http.Response response) =>
    http.runWithClient(body, () => MockClient((_) async => response));

Map<String, dynamic> client(int id, {double? lat, double? lng}) => {
      'id': id,
      'name': 'Client $id',
      'latitude': lat,
      'longitude': lng,
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Carte hors ligne', () {
    test('retrouve les clients en cache situés dans la zone visible',
        () async {
      await OfflineCacheService().put('GET:/api/clients?page=1&limit=20', {
        'data': [
          client(1, lat: 5.35, lng: -4.00), // dans la zone
          client(2, lat: 6.80, lng: -5.30), // hors zone
          client(3), // sans GPS
        ],
      });
      await OfflineCacheService().put('GET:/api/clients?page=2&limit=20', {
        'data': [
          client(1, lat: 5.35, lng: -4.00), // doublon d'une autre page
          client(4, lat: 5.30, lng: -4.05),
        ],
      });

      final clients = await ClientService().cachedClientsInBounds(
        north: 5.4,
        south: 5.2,
        east: -3.9,
        west: -4.1,
      );

      expect(clients.map((c) => c.id).toList()..sort(), [1, 4]);
    });
  });

  group('Visites hors ligne', () {
    final page = {
      'data': [
        {'id': 7, 'client_id': 1, 'user_id': 3, 'status': 'completed'},
      ],
    };

    test('la liste téléchargée en ligne reste affichée hors ligne', () async {
      await online(() => VisitApiService().getVisits(), json(200, page));

      final response = await offline(() => VisitApiService().getVisits());

      expect(response.data.map((v) => v.id), [7]);
    });

    test('sans cache, une erreur de connexion est remontée', () async {
      expect(offline(() => VisitApiService().getVisits()),
          throwsA(isA<VisitApiException>()));
    });
  });

  group('Portefeuille hors ligne', () {
    test('les reçus téléchargés en ligne restent affichés hors ligne',
        () async {
      final receipts = {
        'status': true,
        'data': {'receipts': <Object>[]},
      };
      await online(() => WalletService().getCashReceipts(), json(200, receipts));

      final response = await offline(() => WalletService().getCashReceipts());

      expect(response.status, isTrue);
    });
  });
}
