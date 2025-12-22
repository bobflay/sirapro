import 'package:flutter_test/flutter_test.dart';
import 'package:sirapro/models/terminate_visit_request.dart';

void main() {
  group('TerminateVisitRequest', () {
    group('factory constructors', () {
      test('complete() creates request with completed status', () {
        final request = TerminateVisitRequest.complete(
          latitude: 33.5731,
          longitude: -7.5898,
        );
        expect(request.status, 'completed');
        expect(request.latitude, 33.5731);
        expect(request.longitude, -7.5898);
      });

      test('abort() creates request with aborted status', () {
        final request = TerminateVisitRequest.abort(
          latitude: 33.5731,
          longitude: -7.5898,
        );
        expect(request.status, 'aborted');
        expect(request.latitude, 33.5731);
        expect(request.longitude, -7.5898);
      });
    });

    group('validate()', () {
      test('returns empty list for valid completed request', () {
        final request = TerminateVisitRequest.complete(
          latitude: 33.5731,
          longitude: -7.5898,
        );
        expect(request.validate(), isEmpty);
      });

      test('returns empty list for valid aborted request', () {
        final request = TerminateVisitRequest.abort(
          latitude: 33.5731,
          longitude: -7.5898,
        );
        expect(request.validate(), isEmpty);
      });

      group('status validation', () {
        test('accepts completed status', () {
          final request = TerminateVisitRequest(
            status: 'completed',
            latitude: 0.0,
            longitude: 0.0,
          );
          expect(request.validate().where((e) => e.contains('Status')), isEmpty);
        });

        test('accepts aborted status', () {
          final request = TerminateVisitRequest(
            status: 'aborted',
            latitude: 0.0,
            longitude: 0.0,
          );
          expect(request.validate().where((e) => e.contains('Status')), isEmpty);
        });

        test('returns error for invalid status', () {
          final request = TerminateVisitRequest(
            status: 'cancelled',
            latitude: 0.0,
            longitude: 0.0,
          );
          expect(request.validate(),
              contains('Status must be either "completed" or "aborted"'));
        });

        test('returns error for empty status', () {
          final request = TerminateVisitRequest(
            status: '',
            latitude: 0.0,
            longitude: 0.0,
          );
          expect(request.validate(),
              contains('Status must be either "completed" or "aborted"'));
        });

        test('returns error for uppercase status', () {
          final request = TerminateVisitRequest(
            status: 'COMPLETED',
            latitude: 0.0,
            longitude: 0.0,
          );
          expect(request.validate(),
              contains('Status must be either "completed" or "aborted"'));
        });
      });

      group('latitude validation', () {
        test('accepts latitude at minimum bound (-90)', () {
          final request = TerminateVisitRequest.complete(
            latitude: -90.0,
            longitude: 0.0,
          );
          expect(request.validate().where((e) => e.contains('Latitude')), isEmpty);
        });

        test('accepts latitude at maximum bound (90)', () {
          final request = TerminateVisitRequest.complete(
            latitude: 90.0,
            longitude: 0.0,
          );
          expect(request.validate().where((e) => e.contains('Latitude')), isEmpty);
        });

        test('accepts latitude at zero', () {
          final request = TerminateVisitRequest.complete(
            latitude: 0.0,
            longitude: 0.0,
          );
          expect(request.validate().where((e) => e.contains('Latitude')), isEmpty);
        });

        test('returns error when latitude is below -90', () {
          final request = TerminateVisitRequest.complete(
            latitude: -90.1,
            longitude: 0.0,
          );
          expect(request.validate(),
              contains('Latitude must be between -90 and 90'));
        });

        test('returns error when latitude is above 90', () {
          final request = TerminateVisitRequest.complete(
            latitude: 90.1,
            longitude: 0.0,
          );
          expect(request.validate(),
              contains('Latitude must be between -90 and 90'));
        });
      });

      group('longitude validation', () {
        test('accepts longitude at minimum bound (-180)', () {
          final request = TerminateVisitRequest.complete(
            latitude: 0.0,
            longitude: -180.0,
          );
          expect(
              request.validate().where((e) => e.contains('Longitude')), isEmpty);
        });

        test('accepts longitude at maximum bound (180)', () {
          final request = TerminateVisitRequest.complete(
            latitude: 0.0,
            longitude: 180.0,
          );
          expect(
              request.validate().where((e) => e.contains('Longitude')), isEmpty);
        });

        test('accepts longitude at zero', () {
          final request = TerminateVisitRequest.complete(
            latitude: 0.0,
            longitude: 0.0,
          );
          expect(
              request.validate().where((e) => e.contains('Longitude')), isEmpty);
        });

        test('returns error when longitude is below -180', () {
          final request = TerminateVisitRequest.complete(
            latitude: 0.0,
            longitude: -180.1,
          );
          expect(request.validate(),
              contains('Longitude must be between -180 and 180'));
        });

        test('returns error when longitude is above 180', () {
          final request = TerminateVisitRequest.complete(
            latitude: 0.0,
            longitude: 180.1,
          );
          expect(request.validate(),
              contains('Longitude must be between -180 and 180'));
        });
      });

      group('multiple validation errors', () {
        test('returns all errors when multiple fields are invalid', () {
          final request = TerminateVisitRequest(
            status: 'invalid',
            latitude: 100.0,
            longitude: 200.0,
          );
          final errors = request.validate();

          expect(errors.length, 3);
          expect(
              errors, contains('Status must be either "completed" or "aborted"'));
          expect(errors, contains('Latitude must be between -90 and 90'));
          expect(errors, contains('Longitude must be between -180 and 180'));
        });
      });
    });

    group('isValid', () {
      test('returns true for valid completed request', () {
        final request = TerminateVisitRequest.complete(
          latitude: 33.5731,
          longitude: -7.5898,
        );
        expect(request.isValid, true);
      });

      test('returns true for valid aborted request', () {
        final request = TerminateVisitRequest.abort(
          latitude: 33.5731,
          longitude: -7.5898,
        );
        expect(request.isValid, true);
      });

      test('returns false for invalid status', () {
        final request = TerminateVisitRequest(
          status: 'invalid',
          latitude: 33.5731,
          longitude: -7.5898,
        );
        expect(request.isValid, false);
      });

      test('returns false for invalid coordinates', () {
        final request = TerminateVisitRequest.complete(
          latitude: 100.0,
          longitude: 200.0,
        );
        expect(request.isValid, false);
      });
    });

    group('toJson()', () {
      test('serializes completed request correctly', () {
        final request = TerminateVisitRequest.complete(
          latitude: 33.5731,
          longitude: -7.5898,
        );
        final json = request.toJson();

        expect(json['status'], 'completed');
        expect(json['latitude'], 33.5731);
        expect(json['longitude'], -7.5898);
      });

      test('serializes aborted request correctly', () {
        final request = TerminateVisitRequest.abort(
          latitude: 33.5731,
          longitude: -7.5898,
        );
        final json = request.toJson();

        expect(json['status'], 'aborted');
        expect(json['latitude'], 33.5731);
        expect(json['longitude'], -7.5898);
      });

      test('contains exactly 3 fields', () {
        final request = TerminateVisitRequest.complete(
          latitude: 33.5731,
          longitude: -7.5898,
        );
        final json = request.toJson();

        expect(json.length, 3);
        expect(json.containsKey('status'), true);
        expect(json.containsKey('latitude'), true);
        expect(json.containsKey('longitude'), true);
      });
    });
  });
}
