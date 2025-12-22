import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sirapro/models/client.dart';
import 'package:sirapro/models/create_client_request.dart';
import 'package:sirapro/services/api_service.dart';
import 'package:sirapro/services/client_service.dart';

@GenerateMocks([ApiService])
import 'client_service_test.mocks.dart';

void main() {
  late MockApiService mockApiService;
  late ClientService clientService;

  setUp(() {
    // Reset the singleton before each test
    ClientService.reset();
    mockApiService = MockApiService();
    clientService = ClientService(apiService: mockApiService);
  });

  tearDown(() {
    // Clean up after each test
    ClientService.reset();
  });

  group('ClientService', () {
    group('createClient()', () {
      /// Helper to create a valid request for testing
      CreateClientRequest createValidRequest({
        String code = 'CLI001',
        String name = 'Test Boutique',
        String type = 'Boutique',
        String potential = 'A',
        int baseCommercialeId = 1,
        int zoneId = 1,
        String? managerName,
        String phone = '+212600000000',
        String? whatsapp,
        String? email,
        String city = 'Casablanca',
        String? district,
        String? addressDescription,
        double latitude = 33.5731,
        double longitude = -7.5898,
        String visitFrequency = 'weekly',
        bool? isActive,
      }) {
        return CreateClientRequest(
          code: code,
          name: name,
          type: type,
          potential: potential,
          baseCommercialeId: baseCommercialeId,
          zoneId: zoneId,
          managerName: managerName,
          phone: phone,
          whatsapp: whatsapp,
          email: email,
          city: city,
          district: district,
          addressDescription: addressDescription,
          latitude: latitude,
          longitude: longitude,
          visitFrequency: visitFrequency,
          isActive: isActive,
        );
      }

      test('creates client successfully with valid request', () async {
        final request = createValidRequest();
        final responseData = {
          'status': true,
          'data': {
            'id': 1,
            'name': 'Test Boutique',
            'type': 'Boutique',
            'manager_name': '',
            'phones': ['+212600000000'],
            'city': 'Casablanca',
            'address': '',
            'latitude': 33.5731,
            'longitude': -7.5898,
            'zone_id': 1,
            'commercial_id': null,
            'potential': 'A',
            'visit_frequency': 'weekly',
            'has_open_alert': false,
            'created_at': '2024-01-01T10:00:00.000Z',
            'updated_at': '2024-01-01T10:00:00.000Z',
          },
        };

        when(mockApiService.post('/api/clients', body: anyNamed('body')))
            .thenAnswer((_) async => responseData);

        final client = await clientService.createClient(request);

        expect(client, isA<Client>());
        expect(client.id, 1);
        expect(client.name, 'Test Boutique');
        expect(client.type, 'Boutique');
        expect(client.city, 'Casablanca');
        expect(client.latitude, 33.5731);
        expect(client.longitude, -7.5898);
        expect(client.potential, 'A');
        expect(client.visitFrequency, 'weekly');

        verify(mockApiService.post('/api/clients', body: anyNamed('body')))
            .called(1);
      });

      test('throws ApiException when request validation fails - empty code', () async {
        final request = createValidRequest(code: '');

        expect(
          () => clientService.createClient(request),
          throwsA(
            isA<ApiException>()
                .having((e) => e.message, 'message', 'Le code client est requis')
                .having((e) => e.statusCode, 'statusCode', 422),
          ),
        );

        verifyNever(mockApiService.post(any, body: anyNamed('body')));
      });

      test('throws ApiException when request validation fails - empty name', () async {
        final request = createValidRequest(name: '');

        expect(
          () => clientService.createClient(request),
          throwsA(
            isA<ApiException>()
                .having((e) => e.message, 'message', 'Le nom du client est requis')
                .having((e) => e.statusCode, 'statusCode', 422),
          ),
        );

        verifyNever(mockApiService.post(any, body: anyNamed('body')));
      });

      test('throws ApiException when request validation fails - invalid type', () async {
        final request = createValidRequest(type: 'InvalidType');

        expect(
          () => clientService.createClient(request),
          throwsA(
            isA<ApiException>()
                .having((e) => e.message, 'message', 'Type de client invalide')
                .having((e) => e.statusCode, 'statusCode', 422),
          ),
        );

        verifyNever(mockApiService.post(any, body: anyNamed('body')));
      });

      test('throws ApiException when request validation fails - invalid latitude', () async {
        final request = createValidRequest(latitude: 100.0);

        expect(
          () => clientService.createClient(request),
          throwsA(
            isA<ApiException>()
                .having((e) => e.message, 'message',
                    'Latitude invalide (doit être entre -90 et 90)')
                .having((e) => e.statusCode, 'statusCode', 422),
          ),
        );

        verifyNever(mockApiService.post(any, body: anyNamed('body')));
      });

      test('throws ApiException when request validation fails - invalid email', () async {
        final request = createValidRequest(email: 'invalid-email');

        expect(
          () => clientService.createClient(request),
          throwsA(
            isA<ApiException>()
                .having((e) => e.message, 'message', "Format d'email invalide")
                .having((e) => e.statusCode, 'statusCode', 422),
          ),
        );

        verifyNever(mockApiService.post(any, body: anyNamed('body')));
      });

      test('throws ApiException when API returns status: false with message', () async {
        final request = createValidRequest();
        final responseData = {
          'status': false,
          'message': 'Server error occurred',
        };

        when(mockApiService.post('/api/clients', body: anyNamed('body')))
            .thenAnswer((_) async => responseData);

        expect(
          () => clientService.createClient(request),
          throwsA(
            isA<ApiException>()
                .having((e) => e.message, 'message', 'Server error occurred')
                .having((e) => e.statusCode, 'statusCode', 422),
          ),
        );
      });

      test('throws ApiException with first error from errors map', () async {
        final request = createValidRequest();
        final responseData = {
          'status': false,
          'message': 'Validation failed',
          'errors': {
            'code': ['Le code client existe déjà'],
            'phone': ['Le numéro de téléphone est invalide'],
          },
        };

        when(mockApiService.post('/api/clients', body: anyNamed('body')))
            .thenAnswer((_) async => responseData);

        expect(
          () => clientService.createClient(request),
          throwsA(
            isA<ApiException>()
                .having((e) => e.message, 'message', 'Le code client existe déjà')
                .having((e) => e.statusCode, 'statusCode', 422),
          ),
        );
      });

      test('throws ApiException with default message when no message provided', () async {
        final request = createValidRequest();
        final responseData = {
          'status': false,
        };

        when(mockApiService.post('/api/clients', body: anyNamed('body')))
            .thenAnswer((_) async => responseData);

        expect(
          () => clientService.createClient(request),
          throwsA(
            isA<ApiException>()
                .having((e) => e.message, 'message', 'Client creation failed')
                .having((e) => e.statusCode, 'statusCode', 422),
          ),
        );
      });

      test('sends correct JSON body to API', () async {
        final request = createValidRequest(
          code: 'CLI001',
          name: 'Test Boutique',
          type: 'Boutique',
          potential: 'A',
          baseCommercialeId: 5,
          zoneId: 10,
          managerName: 'John Doe',
          phone: '+212600000000',
          whatsapp: '+212611111111',
          email: 'test@example.com',
          city: 'Casablanca',
          district: 'Maarif',
          addressDescription: 'Near the market',
          latitude: 33.5731,
          longitude: -7.5898,
          visitFrequency: 'weekly',
          isActive: true,
        );

        final responseData = {
          'status': true,
          'data': {
            'id': 1,
            'name': 'Test Boutique',
            'type': 'Boutique',
            'manager_name': 'John Doe',
            'phones': ['+212600000000'],
            'city': 'Casablanca',
            'address': '',
            'created_at': '2024-01-01T10:00:00.000Z',
            'updated_at': '2024-01-01T10:00:00.000Z',
          },
        };

        when(mockApiService.post('/api/clients', body: anyNamed('body')))
            .thenAnswer((_) async => responseData);

        await clientService.createClient(request);

        final captured = verify(
          mockApiService.post('/api/clients', body: captureAnyNamed('body')),
        ).captured.single as Map<String, dynamic>;

        expect(captured['code'], 'CLI001');
        expect(captured['name'], 'Test Boutique');
        expect(captured['type'], 'Boutique');
        expect(captured['potential'], 'A');
        expect(captured['base_commerciale_id'], 5);
        expect(captured['zone_id'], 10);
        expect(captured['manager_name'], 'John Doe');
        expect(captured['phone'], '+212600000000');
        expect(captured['whatsapp'], '+212611111111');
        expect(captured['email'], 'test@example.com');
        expect(captured['city'], 'Casablanca');
        expect(captured['district'], 'Maarif');
        expect(captured['address_description'], 'Near the market');
        expect(captured['latitude'], 33.5731);
        expect(captured['longitude'], -7.5898);
        expect(captured['visit_frequency'], 'weekly');
        expect(captured['is_active'], true);
      });

      test('excludes optional fields when not provided', () async {
        final request = createValidRequest();

        final responseData = {
          'status': true,
          'data': {
            'id': 1,
            'name': 'Test Boutique',
            'type': 'Boutique',
            'manager_name': '',
            'phones': ['+212600000000'],
            'city': 'Casablanca',
            'address': '',
            'created_at': '2024-01-01T10:00:00.000Z',
            'updated_at': '2024-01-01T10:00:00.000Z',
          },
        };

        when(mockApiService.post('/api/clients', body: anyNamed('body')))
            .thenAnswer((_) async => responseData);

        await clientService.createClient(request);

        final captured = verify(
          mockApiService.post('/api/clients', body: captureAnyNamed('body')),
        ).captured.single as Map<String, dynamic>;

        expect(captured.containsKey('manager_name'), isFalse);
        expect(captured.containsKey('whatsapp'), isFalse);
        expect(captured.containsKey('email'), isFalse);
        expect(captured.containsKey('district'), isFalse);
        expect(captured.containsKey('address_description'), isFalse);
        expect(captured.containsKey('is_active'), isFalse);
      });

      test('rethrows ApiException from ApiService', () async {
        final request = createValidRequest();

        when(mockApiService.post('/api/clients', body: anyNamed('body')))
            .thenThrow(ApiException('Network error', statusCode: 500));

        expect(
          () => clientService.createClient(request),
          throwsA(
            isA<ApiException>()
                .having((e) => e.message, 'message', 'Network error')
                .having((e) => e.statusCode, 'statusCode', 500),
          ),
        );
      });
    });

    group('getClient()', () {
      test('fetches client by ID successfully', () async {
        final responseData = {
          'data': {
            'id': 1,
            'name': 'Test Boutique',
            'type': 'Boutique',
            'manager_name': 'John Doe',
            'phones': ['+212600000000'],
            'city': 'Casablanca',
            'address': '123 Main Street',
            'latitude': 33.5731,
            'longitude': -7.5898,
            'zone_id': 5,
            'commercial_id': 10,
            'potential': 'A',
            'visit_frequency': 'weekly',
            'has_open_alert': true,
            'created_at': '2024-01-01T10:00:00.000Z',
            'updated_at': '2024-01-10T15:30:00.000Z',
          },
        };

        when(mockApiService.get('/api/clients/1'))
            .thenAnswer((_) async => responseData);

        final client = await clientService.getClient(1);

        expect(client, isA<Client>());
        expect(client.id, 1);
        expect(client.name, 'Test Boutique');
        expect(client.managerName, 'John Doe');
        expect(client.hasOpenAlert, true);

        verify(mockApiService.get('/api/clients/1')).called(1);
      });
    });

    group('singleton behavior', () {
      test('returns same instance on multiple calls', () {
        ClientService.reset();
        final instance1 = ClientService();
        final instance2 = ClientService();

        expect(identical(instance1, instance2), true);
      });

      test('reset clears the singleton instance', () {
        final instance1 = ClientService(apiService: mockApiService);
        ClientService.reset();

        // Create new mock for second instance
        final newMockApiService = MockApiService();
        final instance2 = ClientService(apiService: newMockApiService);

        // Verify these are different instances by checking they use different API services
        expect(identical(instance1, instance2), false);
      });
    });
  });
}
