import 'package:flutter_test/flutter_test.dart';
import 'package:sirapro/models/api_visit.dart';

void main() {
  group('ApiVisit', () {
    /// Helper to create a test ApiVisit
    ApiVisit createTestVisit({
      int id = 1,
      int clientId = 100,
      int userId = 10,
      int? baseCommercialeId,
      int? zoneId,
      String status = 'started',
      DateTime? startedAt,
      DateTime? endedAt,
      double? latitude,
      double? longitude,
      int? routingItemId,
      int? durationSeconds,
      double? terminationDistance,
      bool? terminatedOutsideRange,
      ApiVisitClient? client,
      ApiVisitUser? user,
    }) {
      return ApiVisit(
        id: id,
        clientId: clientId,
        userId: userId,
        baseCommercialeId: baseCommercialeId,
        zoneId: zoneId,
        status: status,
        startedAt: startedAt,
        endedAt: endedAt,
        latitude: latitude,
        longitude: longitude,
        routingItemId: routingItemId,
        durationSeconds: durationSeconds,
        terminationDistance: terminationDistance,
        terminatedOutsideRange: terminatedOutsideRange,
        client: client,
        user: user,
      );
    }

    group('status checks', () {
      test('isActive returns true when status is started', () {
        final visit = createTestVisit(status: 'started');
        expect(visit.isActive, true);
        expect(visit.isCompleted, false);
        expect(visit.isAborted, false);
      });

      test('isCompleted returns true when status is completed', () {
        final visit = createTestVisit(status: 'completed');
        expect(visit.isActive, false);
        expect(visit.isCompleted, true);
        expect(visit.isAborted, false);
      });

      test('isAborted returns true when status is aborted', () {
        final visit = createTestVisit(status: 'aborted');
        expect(visit.isActive, false);
        expect(visit.isCompleted, false);
        expect(visit.isAborted, true);
      });

      test('all status checks return false for unknown status', () {
        final visit = createTestVisit(status: 'unknown');
        expect(visit.isActive, false);
        expect(visit.isCompleted, false);
        expect(visit.isAborted, false);
      });
    });

    group('duration', () {
      test('returns duration from durationSeconds when available', () {
        final visit = createTestVisit(durationSeconds: 3600);
        expect(visit.duration, const Duration(hours: 1));
      });

      test('calculates duration from startedAt and endedAt when durationSeconds is null', () {
        final startTime = DateTime(2024, 1, 1, 10, 0);
        final endTime = DateTime(2024, 1, 1, 11, 30);
        final visit = createTestVisit(
          startedAt: startTime,
          endedAt: endTime,
          durationSeconds: null,
        );
        expect(visit.duration, const Duration(hours: 1, minutes: 30));
      });

      test('prefers durationSeconds over calculated duration', () {
        final startTime = DateTime(2024, 1, 1, 10, 0);
        final endTime = DateTime(2024, 1, 1, 11, 30);
        final visit = createTestVisit(
          startedAt: startTime,
          endedAt: endTime,
          durationSeconds: 7200, // 2 hours
        );
        // Should use durationSeconds (2 hours), not calculated (1.5 hours)
        expect(visit.duration, const Duration(hours: 2));
      });

      test('returns null when no duration info is available', () {
        final visit = createTestVisit(
          startedAt: null,
          endedAt: null,
          durationSeconds: null,
        );
        expect(visit.duration, isNull);
      });

      test('returns null when only startedAt is available', () {
        final visit = createTestVisit(
          startedAt: DateTime(2024, 1, 1, 10, 0),
          endedAt: null,
          durationSeconds: null,
        );
        expect(visit.duration, isNull);
      });

      test('returns null when only endedAt is available', () {
        final visit = createTestVisit(
          startedAt: null,
          endedAt: DateTime(2024, 1, 1, 10, 0),
          durationSeconds: null,
        );
        expect(visit.duration, isNull);
      });
    });

    group('fromJson()', () {
      test('parses complete visit data correctly', () {
        final json = {
          'id': 1,
          'client_id': 100,
          'user_id': 10,
          'base_commerciale_id': 5,
          'zone_id': 3,
          'status': 'started',
          'started_at': '2024-01-01T10:00:00.000Z',
          'ended_at': '2024-01-01T11:30:00.000Z',
          'latitude': 33.5731,
          'longitude': -7.5898,
          'routing_item_id': 50,
          'duration_seconds': 5400,
          'client': {
            'id': 100,
            'name': 'Test Client',
            'type': 'Boutique',
            'city': 'Casablanca',
          },
          'user': {
            'id': 10,
            'name': 'Test User',
          },
        };

        final visit = ApiVisit.fromJson(json);

        expect(visit.id, 1);
        expect(visit.clientId, 100);
        expect(visit.userId, 10);
        expect(visit.baseCommercialeId, 5);
        expect(visit.zoneId, 3);
        expect(visit.status, 'started');
        expect(visit.startedAt, DateTime.parse('2024-01-01T10:00:00.000Z'));
        expect(visit.endedAt, DateTime.parse('2024-01-01T11:30:00.000Z'));
        expect(visit.latitude, 33.5731);
        expect(visit.longitude, -7.5898);
        expect(visit.routingItemId, 50);
        expect(visit.durationSeconds, 5400);
        expect(visit.client?.id, 100);
        expect(visit.client?.name, 'Test Client');
        expect(visit.user?.id, 10);
        expect(visit.user?.name, 'Test User');
      });

      test('parses termination fields correctly', () {
        final json = {
          'id': 1,
          'client_id': 100,
          'user_id': 10,
          'status': 'completed',
          'termination_distance': 450.25,
          'terminated_outside_range': true,
        };

        final visit = ApiVisit.fromJson(json);

        expect(visit.terminationDistance, 450.25);
        expect(visit.terminatedOutsideRange, true);
      });

      test('handles null optional fields', () {
        final json = {
          'id': 1,
          'client_id': 100,
          'user_id': 10,
          'status': 'started',
        };

        final visit = ApiVisit.fromJson(json);

        expect(visit.id, 1);
        expect(visit.clientId, 100);
        expect(visit.userId, 10);
        expect(visit.status, 'started');
        expect(visit.baseCommercialeId, isNull);
        expect(visit.zoneId, isNull);
        expect(visit.startedAt, isNull);
        expect(visit.endedAt, isNull);
        expect(visit.latitude, isNull);
        expect(visit.longitude, isNull);
        expect(visit.routingItemId, isNull);
        expect(visit.durationSeconds, isNull);
        expect(visit.terminationDistance, isNull);
        expect(visit.terminatedOutsideRange, isNull);
        expect(visit.client, isNull);
        expect(visit.user, isNull);
      });

      test('converts numeric coordinates correctly', () {
        final json = {
          'id': 1,
          'client_id': 100,
          'user_id': 10,
          'status': 'started',
          'latitude': 33,
          'longitude': -7,
        };

        final visit = ApiVisit.fromJson(json);

        expect(visit.latitude, 33.0);
        expect(visit.longitude, -7.0);
      });
    });

    group('toJson()', () {
      test('serializes all fields correctly', () {
        final startTime = DateTime.parse('2024-01-01T10:00:00.000Z');
        final endTime = DateTime.parse('2024-01-01T11:30:00.000Z');
        final client = ApiVisitClient(
          id: 100,
          name: 'Test Client',
          type: 'Boutique',
          city: 'Casablanca',
        );
        final user = ApiVisitUser(id: 10, name: 'Test User');

        final visit = createTestVisit(
          id: 1,
          clientId: 100,
          userId: 10,
          baseCommercialeId: 5,
          zoneId: 3,
          status: 'started',
          startedAt: startTime,
          endedAt: endTime,
          latitude: 33.5731,
          longitude: -7.5898,
          routingItemId: 50,
          durationSeconds: 5400,
          terminationDistance: 450.25,
          terminatedOutsideRange: true,
          client: client,
          user: user,
        );

        final json = visit.toJson();

        expect(json['id'], 1);
        expect(json['client_id'], 100);
        expect(json['user_id'], 10);
        expect(json['base_commerciale_id'], 5);
        expect(json['zone_id'], 3);
        expect(json['status'], 'started');
        expect(json['started_at'], startTime.toIso8601String());
        expect(json['ended_at'], endTime.toIso8601String());
        expect(json['latitude'], 33.5731);
        expect(json['longitude'], -7.5898);
        expect(json['routing_item_id'], 50);
        expect(json['duration_seconds'], 5400);
        expect(json['termination_distance'], 450.25);
        expect(json['terminated_outside_range'], true);
        expect(json['client'], isNotNull);
        expect(json['user'], isNotNull);
      });

      test('handles null fields', () {
        final visit = createTestVisit();
        final json = visit.toJson();

        expect(json['started_at'], isNull);
        expect(json['ended_at'], isNull);
        expect(json['latitude'], isNull);
        expect(json['longitude'], isNull);
        expect(json['termination_distance'], isNull);
        expect(json['terminated_outside_range'], isNull);
        expect(json['client'], isNull);
        expect(json['user'], isNull);
      });
    });

    group('copyWith()', () {
      test('copies all fields when no arguments provided', () {
        final startTime = DateTime(2024, 1, 1, 10, 0);
        final original = createTestVisit(
          id: 1,
          clientId: 100,
          userId: 10,
          baseCommercialeId: 5,
          zoneId: 3,
          status: 'started',
          startedAt: startTime,
          latitude: 33.5731,
          longitude: -7.5898,
          terminationDistance: 5.23,
          terminatedOutsideRange: false,
        );

        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.clientId, original.clientId);
        expect(copy.userId, original.userId);
        expect(copy.baseCommercialeId, original.baseCommercialeId);
        expect(copy.zoneId, original.zoneId);
        expect(copy.status, original.status);
        expect(copy.startedAt, original.startedAt);
        expect(copy.latitude, original.latitude);
        expect(copy.longitude, original.longitude);
        expect(copy.terminationDistance, original.terminationDistance);
        expect(copy.terminatedOutsideRange, original.terminatedOutsideRange);
      });

      test('updates specified fields', () {
        final original = createTestVisit(status: 'started');

        final copy = original.copyWith(
          status: 'completed',
          endedAt: DateTime(2024, 1, 1, 11, 30),
          durationSeconds: 5400,
          terminationDistance: 450.25,
          terminatedOutsideRange: true,
        );

        expect(copy.status, 'completed');
        expect(copy.endedAt, DateTime(2024, 1, 1, 11, 30));
        expect(copy.durationSeconds, 5400);
        expect(copy.terminationDistance, 450.25);
        expect(copy.terminatedOutsideRange, true);
        // Other fields unchanged
        expect(copy.id, original.id);
        expect(copy.clientId, original.clientId);
      });
    });

    group('JSON round-trip', () {
      test('serializes and deserializes correctly', () {
        final startTime = DateTime.parse('2024-01-01T10:00:00.000Z');
        final client = ApiVisitClient(
          id: 100,
          name: 'Test Client',
          type: 'Boutique',
          city: 'Casablanca',
        );
        final user = ApiVisitUser(id: 10, name: 'Test User');

        final original = createTestVisit(
          id: 1,
          clientId: 100,
          userId: 10,
          baseCommercialeId: 5,
          zoneId: 3,
          status: 'started',
          startedAt: startTime,
          latitude: 33.5731,
          longitude: -7.5898,
          routingItemId: 50,
          client: client,
          user: user,
        );

        final json = original.toJson();
        final restored = ApiVisit.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.clientId, original.clientId);
        expect(restored.userId, original.userId);
        expect(restored.baseCommercialeId, original.baseCommercialeId);
        expect(restored.zoneId, original.zoneId);
        expect(restored.status, original.status);
        expect(restored.startedAt, original.startedAt);
        expect(restored.latitude, original.latitude);
        expect(restored.longitude, original.longitude);
        expect(restored.routingItemId, original.routingItemId);
        expect(restored.client?.name, original.client?.name);
        expect(restored.user?.name, original.user?.name);
      });
    });
  });

  group('ApiVisitClient', () {
    group('fromJson()', () {
      test('parses complete data correctly', () {
        final json = {
          'id': 100,
          'name': 'Test Client',
          'type': 'Boutique',
          'city': 'Casablanca',
        };

        final client = ApiVisitClient.fromJson(json);

        expect(client.id, 100);
        expect(client.name, 'Test Client');
        expect(client.type, 'Boutique');
        expect(client.city, 'Casablanca');
      });

      test('handles null optional fields', () {
        final json = {
          'id': 100,
          'name': 'Test Client',
        };

        final client = ApiVisitClient.fromJson(json);

        expect(client.id, 100);
        expect(client.name, 'Test Client');
        expect(client.type, isNull);
        expect(client.city, isNull);
      });
    });

    group('toJson()', () {
      test('serializes all fields correctly', () {
        final client = ApiVisitClient(
          id: 100,
          name: 'Test Client',
          type: 'Boutique',
          city: 'Casablanca',
        );

        final json = client.toJson();

        expect(json['id'], 100);
        expect(json['name'], 'Test Client');
        expect(json['type'], 'Boutique');
        expect(json['city'], 'Casablanca');
      });
    });
  });

  group('ApiVisitUser', () {
    group('fromJson()', () {
      test('parses data correctly', () {
        final json = {
          'id': 10,
          'name': 'Test User',
        };

        final user = ApiVisitUser.fromJson(json);

        expect(user.id, 10);
        expect(user.name, 'Test User');
      });
    });

    group('toJson()', () {
      test('serializes all fields correctly', () {
        final user = ApiVisitUser(id: 10, name: 'Test User');

        final json = user.toJson();

        expect(json['id'], 10);
        expect(json['name'], 'Test User');
      });
    });
  });
}
