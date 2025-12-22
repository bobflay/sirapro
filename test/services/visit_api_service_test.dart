import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sirapro/models/api_visit.dart';
import 'package:sirapro/models/start_visit_request.dart';
import 'package:sirapro/models/terminate_visit_request.dart';
import 'package:sirapro/services/api_service.dart';
import 'package:sirapro/services/visit_api_service.dart';

@GenerateMocks([ApiService])
import 'visit_api_service_test.mocks.dart';

void main() {
  late MockApiService mockApiService;
  late VisitApiService visitApiService;

  setUp(() {
    VisitApiService.resetInstance();
    mockApiService = MockApiService();
    visitApiService = VisitApiService(apiService: mockApiService);
  });

  tearDown(() {
    VisitApiService.resetInstance();
  });

  group('VisitApiService', () {
    group('startVisit()', () {
      test('starts visit successfully with valid request', () async {
        final request = StartVisitRequest(
          clientId: 100,
          latitude: 33.5731,
          longitude: -7.5898,
        );

        final responseData = {
          'status': true,
          'message': 'Visit started successfully',
          'data': {
            'id': 1,
            'client_id': 100,
            'user_id': 10,
            'status': 'started',
            'started_at': '2024-01-01T10:00:00.000Z',
            'latitude': 33.5731,
            'longitude': -7.5898,
            'client': {
              'id': 100,
              'name': 'Test Client',
            },
          },
        };

        when(mockApiService.post('/api/visits', body: anyNamed('body')))
            .thenAnswer((_) async => responseData);

        final visit = await visitApiService.startVisit(request);

        expect(visit, isA<ApiVisit>());
        expect(visit.id, 1);
        expect(visit.clientId, 100);
        expect(visit.status, 'started');
        expect(visit.isActive, true);

        verify(mockApiService.post('/api/visits', body: anyNamed('body')))
            .called(1);
      });

      test('includes routingItemId when provided', () async {
        final request = StartVisitRequest(
          clientId: 100,
          latitude: 33.5731,
          longitude: -7.5898,
          routingItemId: 50,
        );

        final responseData = {
          'status': true,
          'message': 'Visit started successfully',
          'data': {
            'id': 1,
            'client_id': 100,
            'user_id': 10,
            'status': 'started',
            'routing_item_id': 50,
          },
        };

        when(mockApiService.post('/api/visits', body: anyNamed('body')))
            .thenAnswer((_) async => responseData);

        await visitApiService.startVisit(request);

        final captured = verify(
          mockApiService.post('/api/visits', body: captureAnyNamed('body')),
        ).captured.single as Map<String, dynamic>;

        expect(captured['routing_item_id'], 50);
      });

      test('throws VisitApiException when request validation fails', () async {
        final request = StartVisitRequest(
          clientId: 0, // Invalid
          latitude: 33.5731,
          longitude: -7.5898,
        );

        expect(
          () => visitApiService.startVisit(request),
          throwsA(
            isA<VisitApiException>()
                .having((e) => e.message, 'message', 'Client ID is required')
                .having((e) => e.statusCode, 'statusCode', 400),
          ),
        );

        verifyNever(mockApiService.post(any, body: anyNamed('body')));
      });

      test('throws VisitApiException when latitude is invalid', () async {
        final request = StartVisitRequest(
          clientId: 100,
          latitude: 100.0, // Invalid
          longitude: -7.5898,
        );

        expect(
          () => visitApiService.startVisit(request),
          throwsA(
            isA<VisitApiException>().having(
              (e) => e.message,
              'message',
              'Latitude must be between -90 and 90',
            ),
          ),
        );
      });

      test('throws VisitApiException when response has no data', () async {
        final request = StartVisitRequest(
          clientId: 100,
          latitude: 33.5731,
          longitude: -7.5898,
        );

        final responseData = {
          'status': true,
          'message': 'Success',
          'data': null,
        };

        when(mockApiService.post('/api/visits', body: anyNamed('body')))
            .thenAnswer((_) async => responseData);

        expect(
          () => visitApiService.startVisit(request),
          throwsA(
            isA<VisitApiException>()
                .having((e) => e.message, 'message', 'Invalid response from server'),
          ),
        );
      });

      test('handles proximity error from API', () async {
        final request = StartVisitRequest(
          clientId: 100,
          latitude: 33.5731,
          longitude: -7.5898,
        );

        when(mockApiService.post('/api/visits', body: anyNamed('body')))
            .thenThrow(ApiException(
          'You are 127.45 meters from the client. Maximum distance is 15 meters.',
          statusCode: 422,
        ));

        try {
          await visitApiService.startVisit(request);
          fail('Should have thrown');
        } on VisitApiException catch (e) {
          expect(e.isProximityError, true);
          expect(e.statusCode, 422);
          expect(e.proximityDetails, isNotNull);
        }
      });

      test('handles active visit error from API', () async {
        final request = StartVisitRequest(
          clientId: 100,
          latitude: 33.5731,
          longitude: -7.5898,
        );

        when(mockApiService.post('/api/visits', body: anyNamed('body')))
            .thenThrow(ApiException(
          'You have an unterminated visit.',
          statusCode: 422,
        ));

        try {
          await visitApiService.startVisit(request);
          fail('Should have thrown');
        } on VisitApiException catch (e) {
          expect(e.hasActiveVisit, true);
          expect(e.statusCode, 422);
        }
      });

      test('handles invalid client error from API', () async {
        final request = StartVisitRequest(
          clientId: 999,
          latitude: 33.5731,
          longitude: -7.5898,
        );

        when(mockApiService.post('/api/visits', body: anyNamed('body')))
            .thenThrow(ApiException(
          'Invalid client_id provided.',
          statusCode: 422,
        ));

        try {
          await visitApiService.startVisit(request);
          fail('Should have thrown');
        } on VisitApiException catch (e) {
          expect(e.isInvalidClient, true);
          expect(e.statusCode, 422);
        }
      });
    });

    group('terminateVisit()', () {
      test('completes visit successfully within range', () async {
        final request = TerminateVisitRequest.complete(
          latitude: 33.5731,
          longitude: -7.5898,
        );

        final responseData = {
          'status': true,
          'message': 'Visit terminated successfully',
          'data': {
            'id': 1,
            'client_id': 100,
            'user_id': 10,
            'status': 'completed',
            'started_at': '2024-01-01T10:00:00.000Z',
            'ended_at': '2024-01-01T11:30:00.000Z',
            'duration_seconds': 5400,
            'termination_distance': 5.23,
            'terminated_outside_range': false,
          },
        };

        when(mockApiService.post('/api/visits/1/terminate', body: anyNamed('body')))
            .thenAnswer((_) async => responseData);

        final result = await visitApiService.terminateVisit(1, request);

        expect(result.visit.id, 1);
        expect(result.visit.status, 'completed');
        expect(result.visit.isCompleted, true);
        expect(result.visit.durationSeconds, 5400);
        expect(result.warning, isNull);
        expect(result.terminatedOutsideRange, false);
        expect(result.terminationDistance, 5.23);
      });

      test('completes visit successfully outside range with warning', () async {
        final request = TerminateVisitRequest.complete(
          latitude: 33.593000,
          longitude: -7.608000,
        );

        final responseData = {
          'status': true,
          'message': 'Visit terminated successfully',
          'warning': 'Warning: Visit was terminated 450.25 meters away from the client location. The allowed range is 300 meters.',
          'data': {
            'id': 1,
            'client_id': 100,
            'user_id': 10,
            'status': 'completed',
            'started_at': '2024-01-01T10:00:00.000Z',
            'ended_at': '2024-01-01T11:30:00.000Z',
            'duration_seconds': 5400,
            'termination_distance': 450.25,
            'terminated_outside_range': true,
          },
        };

        when(mockApiService.post('/api/visits/1/terminate', body: anyNamed('body')))
            .thenAnswer((_) async => responseData);

        final result = await visitApiService.terminateVisit(1, request);

        expect(result.visit.id, 1);
        expect(result.visit.status, 'completed');
        expect(result.visit.isCompleted, true);
        expect(result.warning, contains('450.25 meters'));
        expect(result.terminatedOutsideRange, true);
        expect(result.terminationDistance, 450.25);
      });

      test('aborts visit successfully', () async {
        final request = TerminateVisitRequest.abort(
          latitude: 33.5731,
          longitude: -7.5898,
        );

        final responseData = {
          'status': true,
          'message': 'Visit aborted',
          'data': {
            'id': 1,
            'client_id': 100,
            'user_id': 10,
            'status': 'aborted',
          },
        };

        when(mockApiService.post('/api/visits/1/terminate', body: anyNamed('body')))
            .thenAnswer((_) async => responseData);

        final result = await visitApiService.terminateVisit(1, request);

        expect(result.visit.status, 'aborted');
        expect(result.visit.isAborted, true);
        expect(result.warning, isNull);
      });

      test('throws VisitApiException when request validation fails', () async {
        final request = TerminateVisitRequest(
          status: 'invalid',
          latitude: 33.5731,
          longitude: -7.5898,
        );

        expect(
          () => visitApiService.terminateVisit(1, request),
          throwsA(
            isA<VisitApiException>().having(
              (e) => e.message,
              'message',
              'Status must be either "completed" or "aborted"',
            ),
          ),
        );

        verifyNever(mockApiService.post(any, body: anyNamed('body')));
      });

      test('throws VisitApiException when response has no data', () async {
        final request = TerminateVisitRequest.complete(
          latitude: 33.5731,
          longitude: -7.5898,
        );

        final responseData = {
          'status': true,
          'message': 'Success',
          'data': null,
        };

        when(mockApiService.post('/api/visits/1/terminate', body: anyNamed('body')))
            .thenAnswer((_) async => responseData);

        expect(
          () => visitApiService.terminateVisit(1, request),
          throwsA(
            isA<VisitApiException>()
                .having((e) => e.message, 'message', 'Invalid response from server'),
          ),
        );
      });

      test('handles already terminated error from API', () async {
        final request = TerminateVisitRequest.complete(
          latitude: 33.5731,
          longitude: -7.5898,
        );

        when(mockApiService.post('/api/visits/1/terminate', body: anyNamed('body')))
            .thenThrow(ApiException(
          'Visit is already terminated.',
          statusCode: 422,
        ));

        try {
          await visitApiService.terminateVisit(1, request);
          fail('Should have thrown');
        } on VisitApiException catch (e) {
          expect(e.isAlreadyTerminated, true);
          expect(e.statusCode, 422);
        }
      });

      test('handles not found error from API', () async {
        final request = TerminateVisitRequest.complete(
          latitude: 33.5731,
          longitude: -7.5898,
        );

        when(mockApiService.post('/api/visits/999/terminate', body: anyNamed('body')))
            .thenThrow(ApiException(
          'Visit not found.',
          statusCode: 404,
        ));

        try {
          await visitApiService.terminateVisit(999, request);
          fail('Should have thrown');
        } on VisitApiException catch (e) {
          expect(e.isNotFound, true);
          expect(e.statusCode, 404);
        }
      });

      test('handles unauthorized error from API', () async {
        final request = TerminateVisitRequest.complete(
          latitude: 33.5731,
          longitude: -7.5898,
        );

        when(mockApiService.post('/api/visits/1/terminate', body: anyNamed('body')))
            .thenThrow(ApiException(
          'Not authorized to terminate this visit.',
          statusCode: 403,
        ));

        try {
          await visitApiService.terminateVisit(1, request);
          fail('Should have thrown');
        } on VisitApiException catch (e) {
          expect(e.isUnauthorized, true);
          expect(e.statusCode, 403);
        }
      });
    });

    group('getActiveVisit()', () {
      test('returns active visit when one exists', () async {
        final responseData = {
          'status': true,
          'message': 'Active visit found',
          'data': {
            'id': 1,
            'client_id': 100,
            'user_id': 10,
            'status': 'started',
            'started_at': '2024-01-01T10:00:00.000Z',
          },
        };

        when(mockApiService.get('/api/visits/active'))
            .thenAnswer((_) async => responseData);

        final visit = await visitApiService.getActiveVisit();

        expect(visit, isNotNull);
        expect(visit?.id, 1);
        expect(visit?.isActive, true);
      });

      test('returns null when no active visit (404)', () async {
        when(mockApiService.get('/api/visits/active'))
            .thenThrow(ApiException('Not found', statusCode: 404));

        final visit = await visitApiService.getActiveVisit();

        expect(visit, isNull);
      });

      test('returns null when response is null', () async {
        when(mockApiService.get('/api/visits/active'))
            .thenAnswer((_) async => null);

        final visit = await visitApiService.getActiveVisit();

        expect(visit, isNull);
      });

      test('returns null when data is null', () async {
        final responseData = {
          'status': true,
          'message': 'No active visit',
          'data': null,
        };

        when(mockApiService.get('/api/visits/active'))
            .thenAnswer((_) async => responseData);

        final visit = await visitApiService.getActiveVisit();

        expect(visit, isNull);
      });

      test('rethrows non-404 errors', () async {
        when(mockApiService.get('/api/visits/active'))
            .thenThrow(ApiException('Server error', statusCode: 500));

        expect(
          () => visitApiService.getActiveVisit(),
          throwsA(isA<ApiException>()),
        );
      });
    });

    group('singleton behavior', () {
      test('returns same instance on multiple calls', () {
        VisitApiService.resetInstance();
        final instance1 = VisitApiService(apiService: mockApiService);
        final instance2 = VisitApiService();

        expect(identical(instance1, instance2), true);
      });

      test('resetInstance clears singleton', () {
        final instance1 = VisitApiService(apiService: mockApiService);
        VisitApiService.resetInstance();

        final newMock = MockApiService();
        final instance2 = VisitApiService(apiService: newMock);

        expect(identical(instance1, instance2), false);
      });
    });
  });

  group('VisitApiException', () {
    test('isProximityError detects proximity errors by errorKey', () {
      final exception = VisitApiException(
        'Too far from client',
        errorKey: 'proximity',
      );
      expect(exception.isProximityError, true);
    });

    test('isProximityError detects proximity errors by errors map', () {
      final exception = VisitApiException(
        'Too far from client',
        errors: {
          'proximity': ['You are 50 meters away']
        },
      );
      expect(exception.isProximityError, true);
    });

    test('hasActiveVisit detects active visit errors', () {
      final exception = VisitApiException(
        'Active visit exists',
        errorKey: 'visit',
      );
      expect(exception.hasActiveVisit, true);
    });

    test('isInvalidClient detects invalid client errors', () {
      final exception = VisitApiException(
        'Invalid client',
        errorKey: 'client_id',
      );
      expect(exception.isInvalidClient, true);
    });

    test('isUnauthorized checks status code', () {
      final exception = VisitApiException(
        'Forbidden',
        statusCode: 403,
      );
      expect(exception.isUnauthorized, true);
    });

    test('isNotFound checks status code', () {
      final exception = VisitApiException(
        'Not found',
        statusCode: 404,
      );
      expect(exception.isNotFound, true);
    });

    test('isAlreadyTerminated detects status errors', () {
      final exception = VisitApiException(
        'Already terminated',
        errorKey: 'status',
      );
      expect(exception.isAlreadyTerminated, true);
    });

    test('proximityDetails returns first proximity error', () {
      final exception = VisitApiException(
        'Too far',
        errors: {
          'proximity': ['Current distance: 127.45 meters']
        },
      );
      expect(exception.proximityDetails, 'Current distance: 127.45 meters');
    });

    test('proximityDetails returns null when no proximity errors', () {
      final exception = VisitApiException('Error');
      expect(exception.proximityDetails, isNull);
    });

    test('firstErrorDetail returns first error from errors map', () {
      final exception = VisitApiException(
        'Validation failed',
        errors: {
          'client_id': ['Invalid client'],
          'latitude': ['Out of range'],
        },
      );
      expect(exception.firstErrorDetail, isNotNull);
    });

    test('firstErrorDetail returns null when no errors', () {
      final exception = VisitApiException('Error');
      expect(exception.firstErrorDetail, isNull);
    });

    test('toString returns message', () {
      final exception = VisitApiException('Test error message');
      expect(exception.toString(), 'Test error message');
    });
  });

  group('VisitApiResponse', () {
    test('fromJson parses complete response', () {
      final json = {
        'status': true,
        'message': 'Success',
        'data': {
          'id': 1,
          'client_id': 100,
          'user_id': 10,
          'status': 'started',
        },
      };

      final response = VisitApiResponse.fromJson(json);

      expect(response.status, true);
      expect(response.message, 'Success');
      expect(response.warning, isNull);
      expect(response.data, isNotNull);
      expect(response.data?.id, 1);
    });

    test('fromJson parses response with warning', () {
      final json = {
        'status': true,
        'message': 'Visit terminated successfully',
        'warning': 'Warning: Visit was terminated 450.25 meters away from the client location.',
        'data': {
          'id': 1,
          'client_id': 100,
          'user_id': 10,
          'status': 'completed',
          'termination_distance': 450.25,
          'terminated_outside_range': true,
        },
      };

      final response = VisitApiResponse.fromJson(json);

      expect(response.status, true);
      expect(response.message, 'Visit terminated successfully');
      expect(response.warning, contains('450.25 meters'));
      expect(response.data, isNotNull);
      expect(response.data?.terminationDistance, 450.25);
      expect(response.data?.terminatedOutsideRange, true);
    });

    test('fromJson handles null data', () {
      final json = {
        'status': false,
        'message': 'Error',
        'data': null,
      };

      final response = VisitApiResponse.fromJson(json);

      expect(response.status, false);
      expect(response.message, 'Error');
      expect(response.warning, isNull);
      expect(response.data, isNull);
    });
  });

  group('VisitTerminationResult', () {
    test('terminatedOutsideRange returns true when visit has flag set', () {
      final visit = ApiVisit(
        id: 1,
        clientId: 100,
        userId: 10,
        status: 'completed',
        terminationDistance: 450.25,
        terminatedOutsideRange: true,
      );
      final result = VisitTerminationResult(
        visit: visit,
        warning: 'Warning: Visit was terminated outside range',
      );

      expect(result.terminatedOutsideRange, true);
      expect(result.terminationDistance, 450.25);
      expect(result.warning, isNotNull);
    });

    test('terminatedOutsideRange returns false when visit has flag unset', () {
      final visit = ApiVisit(
        id: 1,
        clientId: 100,
        userId: 10,
        status: 'completed',
        terminationDistance: 5.23,
        terminatedOutsideRange: false,
      );
      final result = VisitTerminationResult(visit: visit);

      expect(result.terminatedOutsideRange, false);
      expect(result.terminationDistance, 5.23);
      expect(result.warning, isNull);
    });

    test('terminatedOutsideRange returns false when flag is null', () {
      final visit = ApiVisit(
        id: 1,
        clientId: 100,
        userId: 10,
        status: 'completed',
      );
      final result = VisitTerminationResult(visit: visit);

      expect(result.terminatedOutsideRange, false);
      expect(result.terminationDistance, isNull);
    });
  });
}
