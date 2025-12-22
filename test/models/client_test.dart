import 'package:flutter_test/flutter_test.dart';
import 'package:sirapro/models/client.dart';
import 'package:sirapro/models/client_photo.dart';

void main() {
  group('Client', () {
    group('fromJson()', () {
      test('parses complete client data correctly', () {
        final json = {
          'id': 1,
          'name': 'Boutique Test',
          'type': 'Boutique',
          'manager_name': 'John Doe',
          'phones': ['+212600000000', '+212611111111'],
          'city': 'Casablanca',
          'address': '123 Main Street',
          'latitude': 33.5731,
          'longitude': -7.5898,
          'zone_id': 5,
          'commercial_id': 10,
          'potential': 'A',
          'visit_frequency': 'weekly',
          'last_visit_date': '2024-01-15',
          'has_open_alert': true,
          'created_at': '2024-01-01T10:00:00.000Z',
          'updated_at': '2024-01-10T15:30:00.000Z',
          'photos': [
            {
              'id': 1,
              'url': '/photos/facade.jpg',
              'file_name': 'facade.jpg',
              'type': 'facade',
            }
          ],
          'email': 'test@example.com',
          'whatsapp': '+212622222222',
          'district': 'Maarif',
          'zone': 'Zone A',
          'gps_location': '33.5731, -7.5898',
        };

        final client = Client.fromJson(json);

        expect(client.id, 1);
        expect(client.name, 'Boutique Test');
        expect(client.type, 'Boutique');
        expect(client.managerName, 'John Doe');
        expect(client.phones, ['+212600000000', '+212611111111']);
        expect(client.city, 'Casablanca');
        expect(client.address, '123 Main Street');
        expect(client.latitude, 33.5731);
        expect(client.longitude, -7.5898);
        expect(client.zoneId, 5);
        expect(client.commercialId, 10);
        expect(client.potential, 'A');
        expect(client.visitFrequency, 'weekly');
        expect(client.lastVisitDate, DateTime.parse('2024-01-15'));
        expect(client.hasOpenAlert, true);
        expect(client.createdAt, DateTime.parse('2024-01-01T10:00:00.000Z'));
        expect(client.updatedAt, DateTime.parse('2024-01-10T15:30:00.000Z'));
        expect(client.photos.length, 1);
        expect(client.photos.first.id, 1);
        expect(client.email, 'test@example.com');
        expect(client.whatsapp, '+212622222222');
        expect(client.quartier, 'Maarif');
        expect(client.zone, 'Zone A');
        expect(client.gpsLocation, '33.5731, -7.5898');
      });

      test('handles null optional fields', () {
        final json = {
          'id': 1,
          'name': 'Boutique Test',
          'type': 'Boutique',
          'manager_name': 'John Doe',
          'phones': ['+212600000000'],
          'city': 'Casablanca',
          'address': '123 Main Street',
          'latitude': null,
          'longitude': null,
          'zone_id': null,
          'commercial_id': null,
          'potential': null,
          'visit_frequency': null,
          'last_visit_date': null,
          'has_open_alert': null,
          'created_at': '2024-01-01T10:00:00.000Z',
          'updated_at': '2024-01-10T15:30:00.000Z',
        };

        final client = Client.fromJson(json);

        expect(client.latitude, isNull);
        expect(client.longitude, isNull);
        expect(client.zoneId, isNull);
        expect(client.commercialId, isNull);
        expect(client.potential, isNull);
        expect(client.visitFrequency, isNull);
        expect(client.lastVisitDate, isNull);
        expect(client.hasOpenAlert, false);
        expect(client.photos, isEmpty);
      });

      test('handles missing optional fields gracefully', () {
        final json = {
          'id': 1,
          'name': 'Boutique Test',
          'type': 'Boutique',
          'manager_name': 'John Doe',
          'phones': ['+212600000000'],
          'city': 'Casablanca',
          'address': '123 Main Street',
          'created_at': '2024-01-01T10:00:00.000Z',
          'updated_at': '2024-01-10T15:30:00.000Z',
        };

        final client = Client.fromJson(json);

        expect(client.latitude, isNull);
        expect(client.longitude, isNull);
        expect(client.photos, isEmpty);
      });

      test('converts numeric latitude/longitude correctly', () {
        final json = {
          'id': 1,
          'name': 'Boutique Test',
          'type': 'Boutique',
          'manager_name': 'John Doe',
          'phones': ['+212600000000'],
          'city': 'Casablanca',
          'address': '123 Main Street',
          'latitude': 33,
          'longitude': -7,
          'created_at': '2024-01-01T10:00:00.000Z',
          'updated_at': '2024-01-10T15:30:00.000Z',
        };

        final client = Client.fromJson(json);

        expect(client.latitude, 33.0);
        expect(client.longitude, -7.0);
      });
    });

    group('toJson()', () {
      test('serializes client data correctly', () {
        final client = Client(
          id: 1,
          name: 'Boutique Test',
          type: 'Boutique',
          managerName: 'John Doe',
          phones: ['+212600000000'],
          city: 'Casablanca',
          address: '123 Main Street',
          latitude: 33.5731,
          longitude: -7.5898,
          zoneId: 5,
          commercialId: 10,
          potential: 'A',
          visitFrequency: 'weekly',
          lastVisitDate: DateTime(2024, 1, 15),
          hasOpenAlert: true,
          createdAt: DateTime.parse('2024-01-01T10:00:00.000Z'),
          updatedAt: DateTime.parse('2024-01-10T15:30:00.000Z'),
        );

        final json = client.toJson();

        expect(json['id'], 1);
        expect(json['name'], 'Boutique Test');
        expect(json['type'], 'Boutique');
        expect(json['manager_name'], 'John Doe');
        expect(json['phones'], ['+212600000000']);
        expect(json['city'], 'Casablanca');
        expect(json['address'], '123 Main Street');
        expect(json['latitude'], 33.5731);
        expect(json['longitude'], -7.5898);
        expect(json['zone_id'], 5);
        expect(json['commercial_id'], 10);
        expect(json['potential'], 'A');
        expect(json['visit_frequency'], 'weekly');
        expect(json['last_visit_date'], '2024-01-15');
        expect(json['has_open_alert'], true);
      });

      test('handles null lastVisitDate', () {
        final client = Client(
          id: 1,
          name: 'Boutique Test',
          type: 'Boutique',
          managerName: 'John Doe',
          phones: ['+212600000000'],
          city: 'Casablanca',
          address: '123 Main Street',
          hasOpenAlert: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final json = client.toJson();

        expect(json['last_visit_date'], isNull);
      });
    });

    group('legacy constructor', () {
      test('creates client from legacy format', () {
        final client = Client.legacy(
          id: '123',
          boutiqueName: 'Boutique Test',
          type: 'Boutique',
          gerantName: 'John Doe',
          phone: '+212600000000',
          whatsapp: '+212611111111',
          email: 'test@example.com',
          address: '123 Main Street',
          quartier: 'Maarif',
          ville: 'Casablanca',
          zone: 'Zone A',
          gpsLocation: '33.5731, -7.5898',
          potentiel: 'A',
          frequenceVisite: 'weekly',
          status: 'active',
          isActive: true,
          createdAt: DateTime(2024, 1, 1),
        );

        expect(client.id, 123);
        expect(client.name, 'Boutique Test');
        expect(client.type, 'Boutique');
        expect(client.managerName, 'John Doe');
        expect(client.phones, ['+212600000000']);
        expect(client.city, 'Casablanca');
        expect(client.address, '123 Main Street');
        expect(client.latitude, 33.5731);
        expect(client.longitude, -7.5898);
        expect(client.potential, 'A');
        expect(client.visitFrequency, 'weekly');
        expect(client.whatsapp, '+212611111111');
        expect(client.email, 'test@example.com');
        expect(client.quartier, 'Maarif');
        expect(client.zone, 'Zone A');
        expect(client.status, 'active');
        expect(client.isActive, true);
      });

      test('parses GPS location with various formats', () {
        final client1 = Client.legacy(
          id: '1',
          boutiqueName: 'Test',
          type: 'Boutique',
          gerantName: 'Test',
          phone: '123',
          address: 'Test',
          quartier: 'Test',
          ville: 'Test',
          gpsLocation: '33.5731° N, 7.5898° W',
          status: 'active',
          isActive: true,
          createdAt: DateTime.now(),
        );

        expect(client1.latitude, 33.5731);
        expect(client1.longitude, 7.5898);

        final client2 = Client.legacy(
          id: '2',
          boutiqueName: 'Test',
          type: 'Boutique',
          gerantName: 'Test',
          phone: '123',
          address: 'Test',
          quartier: 'Test',
          ville: 'Test',
          gpsLocation: null,
          status: 'active',
          isActive: true,
          createdAt: DateTime.now(),
        );

        expect(client2.latitude, isNull);
        expect(client2.longitude, isNull);
      });

      test('handles non-numeric id by using hashCode', () {
        final client = Client.legacy(
          id: 'non-numeric-id',
          boutiqueName: 'Test',
          type: 'Boutique',
          gerantName: 'Test',
          phone: '123',
          address: 'Test',
          quartier: 'Test',
          ville: 'Test',
          status: 'active',
          isActive: true,
          createdAt: DateTime.now(),
        );

        expect(client.id, 'non-numeric-id'.hashCode);
      });
    });

    group('legacy getters', () {
      test('boutiqueName returns name', () {
        final client = _createTestClient(name: 'Test Boutique');
        expect(client.boutiqueName, 'Test Boutique');
      });

      test('gerantName returns managerName', () {
        final client = _createTestClient(managerName: 'John Doe');
        expect(client.gerantName, 'John Doe');
      });

      test('phone returns first phone number', () {
        final client = _createTestClient(phones: ['+212600000000', '+212611111111']);
        expect(client.phone, '+212600000000');
      });

      test('phone returns empty string when phones is empty', () {
        final client = _createTestClient(phones: []);
        expect(client.phone, '');
      });

      test('ville returns city', () {
        final client = _createTestClient(city: 'Casablanca');
        expect(client.ville, 'Casablanca');
      });

      test('potentiel returns potential', () {
        final client = _createTestClient(potential: 'A');
        expect(client.potentiel, 'A');
      });

      test('frequenceVisite returns visitFrequency', () {
        final client = _createTestClient(visitFrequency: 'weekly');
        expect(client.frequenceVisite, 'weekly');
      });
    });

    group('computed properties', () {
      test('displayName returns name', () {
        final client = _createTestClient(name: 'Test Boutique');
        expect(client.displayName, 'Test Boutique');
      });

      test('primaryPhone returns first phone or null', () {
        final clientWithPhone = _createTestClient(phones: ['+212600000000']);
        expect(clientWithPhone.primaryPhone, '+212600000000');

        final clientWithoutPhone = _createTestClient(phones: []);
        expect(clientWithoutPhone.primaryPhone, isNull);
      });

      test('fullAddress combines address and city', () {
        final client = _createTestClient(
          address: '123 Main Street',
          city: 'Casablanca',
        );
        expect(client.fullAddress, '123 Main Street, Casablanca');
      });

      test('fullAddress includes quartier when available', () {
        final client = _createTestClient(
          address: '123 Main Street',
          city: 'Casablanca',
          quartier: 'Maarif',
        );
        expect(client.fullAddress, '123 Main Street, Maarif, Casablanca');
      });

      test('fullAddress excludes empty quartier', () {
        final client = _createTestClient(
          address: '123 Main Street',
          city: 'Casablanca',
          quartier: '',
        );
        expect(client.fullAddress, '123 Main Street, Casablanca');
      });

      test('hasLocation returns true when both coordinates are set', () {
        final client = _createTestClient(latitude: 33.5731, longitude: -7.5898);
        expect(client.hasLocation, true);
      });

      test('hasLocation returns false when latitude is null', () {
        final client = _createTestClient(latitude: null, longitude: -7.5898);
        expect(client.hasLocation, false);
      });

      test('hasLocation returns false when longitude is null', () {
        final client = _createTestClient(latitude: 33.5731, longitude: null);
        expect(client.hasLocation, false);
      });

      test('hasLocation returns false when both are null', () {
        final client = _createTestClient(latitude: null, longitude: null);
        expect(client.hasLocation, false);
      });
    });

    group('copyWith()', () {
      test('copies all fields when no arguments provided', () {
        final original = _createTestClient(
          id: 1,
          name: 'Original',
          type: 'Boutique',
          managerName: 'Manager',
          phones: ['+212600000000'],
          city: 'Casablanca',
          address: '123 Main',
          latitude: 33.5731,
          longitude: -7.5898,
          potential: 'A',
          visitFrequency: 'weekly',
          hasOpenAlert: true,
        );

        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.name, original.name);
        expect(copy.type, original.type);
        expect(copy.managerName, original.managerName);
        expect(copy.phones, original.phones);
        expect(copy.city, original.city);
        expect(copy.address, original.address);
        expect(copy.latitude, original.latitude);
        expect(copy.longitude, original.longitude);
        expect(copy.potential, original.potential);
        expect(copy.visitFrequency, original.visitFrequency);
        expect(copy.hasOpenAlert, original.hasOpenAlert);
      });

      test('updates specified fields', () {
        final original = _createTestClient(
          name: 'Original',
          city: 'Casablanca',
        );

        final copy = original.copyWith(
          name: 'Updated',
          city: 'Rabat',
        );

        expect(copy.name, 'Updated');
        expect(copy.city, 'Rabat');
      });

      test('supports legacy field name aliases', () {
        final original = _createTestClient(
          name: 'Original',
          managerName: 'Original Manager',
          phones: ['+212600000000'],
          city: 'Casablanca',
          potential: 'A',
          visitFrequency: 'weekly',
        );

        final copy = original.copyWith(
          boutiqueName: 'Updated Boutique',
          gerantName: 'Updated Manager',
          phone: '+212611111111',
          ville: 'Rabat',
          potentiel: 'B',
          frequenceVisite: 'monthly',
        );

        expect(copy.name, 'Updated Boutique');
        expect(copy.managerName, 'Updated Manager');
        expect(copy.phones, ['+212611111111']);
        expect(copy.city, 'Rabat');
        expect(copy.potential, 'B');
        expect(copy.visitFrequency, 'monthly');
      });

      test('updates photos list', () {
        final original = _createTestClient();
        final newPhotos = [
          ClientPhoto(id: 1, url: '/new.jpg', fileName: 'new.jpg'),
        ];

        final copy = original.copyWith(photos: newPhotos);

        expect(copy.photos.length, 1);
        expect(copy.photos.first.id, 1);
      });
    });

    group('equality', () {
      test('two clients with same id are equal', () {
        final client1 = _createTestClient(id: 1, name: 'Client 1');
        final client2 = _createTestClient(id: 1, name: 'Client 2');

        expect(client1 == client2, true);
      });

      test('two clients with different ids are not equal', () {
        final client1 = _createTestClient(id: 1, name: 'Same Name');
        final client2 = _createTestClient(id: 2, name: 'Same Name');

        expect(client1 == client2, false);
      });

      test('hashCode is based on id', () {
        final client1 = _createTestClient(id: 1);
        final client2 = _createTestClient(id: 1);

        expect(client1.hashCode, client2.hashCode);
      });

      test('identical clients are equal', () {
        final client = _createTestClient(id: 1);
        expect(client == client, true);
      });
    });

    group('toString()', () {
      test('returns readable string representation', () {
        final client = _createTestClient(
          id: 1,
          name: 'Test Boutique',
          type: 'Boutique',
          city: 'Casablanca',
        );

        expect(
          client.toString(),
          'Client(id: 1, name: Test Boutique, type: Boutique, city: Casablanca)',
        );
      });
    });
  });
}

/// Helper function to create a test client with default values
Client _createTestClient({
  int id = 1,
  String name = 'Test Client',
  String type = 'Boutique',
  String managerName = 'Test Manager',
  List<String> phones = const ['+212600000000'],
  String city = 'Casablanca',
  String address = '123 Test Street',
  double? latitude,
  double? longitude,
  int? zoneId,
  int? commercialId,
  String? potential,
  String? visitFrequency,
  DateTime? lastVisitDate,
  bool hasOpenAlert = false,
  DateTime? createdAt,
  DateTime? updatedAt,
  List<ClientPhoto> photos = const [],
  String? whatsapp,
  String? email,
  String? quartier,
  String? zone,
  String? gpsLocation,
  String? status,
  bool? isActive,
}) {
  return Client(
    id: id,
    name: name,
    type: type,
    managerName: managerName,
    phones: phones,
    city: city,
    address: address,
    latitude: latitude,
    longitude: longitude,
    zoneId: zoneId,
    commercialId: commercialId,
    potential: potential,
    visitFrequency: visitFrequency,
    lastVisitDate: lastVisitDate,
    hasOpenAlert: hasOpenAlert,
    createdAt: createdAt ?? DateTime.now(),
    updatedAt: updatedAt ?? DateTime.now(),
    photos: photos,
    whatsapp: whatsapp,
    email: email,
    quartier: quartier,
    zone: zone,
    gpsLocation: gpsLocation,
    status: status,
    isActive: isActive,
  );
}
