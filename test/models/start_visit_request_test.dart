import 'package:flutter_test/flutter_test.dart';
import 'package:sirapro/models/start_visit_request.dart';

void main() {
  group('StartVisitRequest', () {
    group('validate()', () {
      test('returns empty list for valid request', () {
        final request = StartVisitRequest(
          clientId: 1,
          latitude: 33.5731,
          longitude: -7.5898,
        );
        expect(request.validate(), isEmpty);
      });

      test('returns empty list for valid request with routingItemId', () {
        final request = StartVisitRequest(
          clientId: 1,
          latitude: 33.5731,
          longitude: -7.5898,
          routingItemId: 100,
        );
        expect(request.validate(), isEmpty);
      });

      group('clientId validation', () {
        test('returns error when clientId is 0', () {
          final request = StartVisitRequest(
            clientId: 0,
            latitude: 33.5731,
            longitude: -7.5898,
          );
          expect(request.validate(), contains('Client ID is required'));
        });

        test('returns error when clientId is negative', () {
          final request = StartVisitRequest(
            clientId: -1,
            latitude: 33.5731,
            longitude: -7.5898,
          );
          expect(request.validate(), contains('Client ID is required'));
        });

        test('accepts positive clientId', () {
          final request = StartVisitRequest(
            clientId: 1,
            latitude: 33.5731,
            longitude: -7.5898,
          );
          expect(request.validate().where((e) => e.contains('Client')), isEmpty);
        });
      });

      group('latitude validation', () {
        test('accepts latitude at minimum bound (-90)', () {
          final request = StartVisitRequest(
            clientId: 1,
            latitude: -90.0,
            longitude: 0.0,
          );
          expect(request.validate().where((e) => e.contains('Latitude')), isEmpty);
        });

        test('accepts latitude at maximum bound (90)', () {
          final request = StartVisitRequest(
            clientId: 1,
            latitude: 90.0,
            longitude: 0.0,
          );
          expect(request.validate().where((e) => e.contains('Latitude')), isEmpty);
        });

        test('accepts latitude at zero', () {
          final request = StartVisitRequest(
            clientId: 1,
            latitude: 0.0,
            longitude: 0.0,
          );
          expect(request.validate().where((e) => e.contains('Latitude')), isEmpty);
        });

        test('returns error when latitude is below -90', () {
          final request = StartVisitRequest(
            clientId: 1,
            latitude: -90.1,
            longitude: 0.0,
          );
          expect(request.validate(),
              contains('Latitude must be between -90 and 90'));
        });

        test('returns error when latitude is above 90', () {
          final request = StartVisitRequest(
            clientId: 1,
            latitude: 90.1,
            longitude: 0.0,
          );
          expect(request.validate(),
              contains('Latitude must be between -90 and 90'));
        });
      });

      group('longitude validation', () {
        test('accepts longitude at minimum bound (-180)', () {
          final request = StartVisitRequest(
            clientId: 1,
            latitude: 0.0,
            longitude: -180.0,
          );
          expect(
              request.validate().where((e) => e.contains('Longitude')), isEmpty);
        });

        test('accepts longitude at maximum bound (180)', () {
          final request = StartVisitRequest(
            clientId: 1,
            latitude: 0.0,
            longitude: 180.0,
          );
          expect(
              request.validate().where((e) => e.contains('Longitude')), isEmpty);
        });

        test('accepts longitude at zero', () {
          final request = StartVisitRequest(
            clientId: 1,
            latitude: 0.0,
            longitude: 0.0,
          );
          expect(
              request.validate().where((e) => e.contains('Longitude')), isEmpty);
        });

        test('returns error when longitude is below -180', () {
          final request = StartVisitRequest(
            clientId: 1,
            latitude: 0.0,
            longitude: -180.1,
          );
          expect(request.validate(),
              contains('Longitude must be between -180 and 180'));
        });

        test('returns error when longitude is above 180', () {
          final request = StartVisitRequest(
            clientId: 1,
            latitude: 0.0,
            longitude: 180.1,
          );
          expect(request.validate(),
              contains('Longitude must be between -180 and 180'));
        });
      });

      group('multiple validation errors', () {
        test('returns all errors when multiple fields are invalid', () {
          final request = StartVisitRequest(
            clientId: 0,
            latitude: 100.0,
            longitude: 200.0,
          );
          final errors = request.validate();

          expect(errors.length, 3);
          expect(errors, contains('Client ID is required'));
          expect(errors, contains('Latitude must be between -90 and 90'));
          expect(errors, contains('Longitude must be between -180 and 180'));
        });
      });
    });

    group('isValid', () {
      test('returns true for valid request', () {
        final request = StartVisitRequest(
          clientId: 1,
          latitude: 33.5731,
          longitude: -7.5898,
        );
        expect(request.isValid, true);
      });

      test('returns false for invalid request', () {
        final request = StartVisitRequest(
          clientId: 0,
          latitude: 33.5731,
          longitude: -7.5898,
        );
        expect(request.isValid, false);
      });
    });

    group('toJson()', () {
      test('serializes required fields correctly', () {
        final request = StartVisitRequest(
          clientId: 1,
          latitude: 33.5731,
          longitude: -7.5898,
        );
        final json = request.toJson();

        expect(json['client_id'], 1);
        expect(json['latitude'], 33.5731);
        expect(json['longitude'], -7.5898);
        expect(json.containsKey('routing_item_id'), false);
      });

      test('includes routingItemId when provided', () {
        final request = StartVisitRequest(
          clientId: 1,
          latitude: 33.5731,
          longitude: -7.5898,
          routingItemId: 100,
        );
        final json = request.toJson();

        expect(json['client_id'], 1);
        expect(json['latitude'], 33.5731);
        expect(json['longitude'], -7.5898);
        expect(json['routing_item_id'], 100);
      });

      test('excludes routingItemId when null', () {
        final request = StartVisitRequest(
          clientId: 1,
          latitude: 33.5731,
          longitude: -7.5898,
          routingItemId: null,
        );
        final json = request.toJson();

        expect(json.containsKey('routing_item_id'), false);
      });
    });
  });
}
