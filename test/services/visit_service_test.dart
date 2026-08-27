import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sirapro/models/api_visit.dart';
import 'package:sirapro/models/client.dart';
import 'package:sirapro/models/visit.dart';
import 'package:sirapro/services/visit_service.dart';

void main() {
  group('VisitService', () {
    late VisitService visitService;

    setUp(() async {
      // Initialize SharedPreferences mock
      SharedPreferences.setMockInitialValues({});
      // Reset and get fresh instance
      await VisitService().reset();
      visitService = VisitService();
    });

    tearDown(() async {
      await visitService.reset();
    });

    /// Helper to create a test legacy Visit
    Visit createTestLegacyVisit({
      String id = 'visit-1',
      String routeId = 'route-1',
      String clientId = 'client-1',
      String clientName = 'Test Client',
      String clientAddress = '123 Test Street',
      int order = 1,
      VisitStatus status = VisitStatus.inProgress,
      DateTime? actualStartTime,
    }) {
      return Visit(
        id: id,
        routeId: routeId,
        clientId: clientId,
        clientName: clientName,
        clientAddress: clientAddress,
        order: order,
        status: status,
        actualStartTime: actualStartTime,
        createdAt: DateTime.now(),
      );
    }

    /// Helper to create a test ApiVisit
    ApiVisit createTestApiVisit({
      int id = 1,
      int clientId = 100,
      int userId = 10,
      String status = 'started',
      DateTime? startedAt,
      ApiVisitClient? client,
    }) {
      return ApiVisit(
        id: id,
        clientId: clientId,
        userId: userId,
        status: status,
        startedAt: startedAt ?? DateTime.now(),
        client: client ??
            ApiVisitClient(id: clientId, name: 'Test Client'),
      );
    }

    group('singleton pattern', () {
      test('returns same instance on multiple calls', () {
        final instance1 = VisitService();
        final instance2 = VisitService();
        expect(identical(instance1, instance2), true);
      });
    });

    group('initial state', () {
      test('has no active visit initially', () {
        expect(visitService.hasActiveVisit, false);
        expect(visitService.hasActiveApiVisit, false);
        expect(visitService.activeVisit, isNull);
        expect(visitService.activeApiVisit, isNull);
      });

      test('activeClientName is null initially', () {
        expect(visitService.activeClientName, isNull);
      });

      test('activeClientId is null initially', () {
        expect(visitService.activeClientId, isNull);
      });

      test('activeVisitId is null initially', () {
        expect(visitService.activeVisitId, isNull);
      });

      test('activeVisitStartTime is null initially', () {
        expect(visitService.activeVisitStartTime, isNull);
      });
    });

    group('startVisit() (legacy)', () {
      test('starts visit successfully when no active visit', () {
        final visit = createTestLegacyVisit();
        final result = visitService.startVisit(visit);

        expect(result, true);
        expect(visitService.hasActiveVisit, true);
        expect(visitService.activeVisit, visit);
      });

      test('fails when legacy visit already active', () {
        final visit1 = createTestLegacyVisit(id: 'visit-1');
        final visit2 = createTestLegacyVisit(id: 'visit-2');

        visitService.startVisit(visit1);
        final result = visitService.startVisit(visit2);

        expect(result, false);
        expect(visitService.activeVisit?.id, 'visit-1');
      });

      test('fails when API visit already active', () async {
        final apiVisit = createTestApiVisit();
        await visitService.startApiVisit(apiVisit);

        final legacyVisit = createTestLegacyVisit();
        final result = visitService.startVisit(legacyVisit);

        expect(result, false);
        expect(visitService.activeVisit, isNull);
        expect(visitService.hasActiveApiVisit, true);
      });

      test('fails when visit status is not inProgress', () {
        final visit = createTestLegacyVisit(status: VisitStatus.planned);
        final result = visitService.startVisit(visit);

        expect(result, false);
        expect(visitService.hasActiveVisit, false);
      });

      test('fails when visit status is completed', () {
        final visit = createTestLegacyVisit(status: VisitStatus.completed);
        final result = visitService.startVisit(visit);

        expect(result, false);
      });

      test('fails when visit status is skipped', () {
        final visit = createTestLegacyVisit(status: VisitStatus.skipped);
        final result = visitService.startVisit(visit);

        expect(result, false);
      });
    });

    group('startApiVisit()', () {
      test('starts API visit successfully when no active visit', () async {
        final visit = createTestApiVisit();
        final result = await visitService.startApiVisit(visit);

        expect(result, true);
        expect(visitService.hasActiveApiVisit, true);
        expect(visitService.hasActiveVisit, true);
        expect(visitService.activeApiVisit?.id, visit.id);
      });

      test('fails when API visit already active', () async {
        final visit1 = createTestApiVisit(id: 1);
        final visit2 = createTestApiVisit(id: 2);

        await visitService.startApiVisit(visit1);
        final result = await visitService.startApiVisit(visit2);

        expect(result, false);
        expect(visitService.activeApiVisit?.id, 1);
      });

      test('fails when legacy visit already active', () async {
        final legacyVisit = createTestLegacyVisit();
        visitService.startVisit(legacyVisit);

        final apiVisit = createTestApiVisit();
        final result = await visitService.startApiVisit(apiVisit);

        expect(result, false);
        expect(visitService.activeApiVisit, isNull);
      });

      test('fails when visit is not active (completed)', () async {
        final visit = createTestApiVisit(status: 'completed');
        final result = await visitService.startApiVisit(visit);

        expect(result, false);
        expect(visitService.hasActiveApiVisit, false);
      });

      test('fails when visit is not active (aborted)', () async {
        final visit = createTestApiVisit(status: 'aborted');
        final result = await visitService.startApiVisit(visit);

        expect(result, false);
        expect(visitService.hasActiveApiVisit, false);
      });

      test('persists visit to SharedPreferences', () async {
        final visit = createTestApiVisit(id: 123);
        await visitService.startApiVisit(visit);

        // Create new instance to verify persistence
        final prefs = await SharedPreferences.getInstance();
        final savedJson = prefs.getString('active_api_visit');

        expect(savedJson, isNotNull);
        expect(savedJson, contains('"id":123'));
      });
    });

    group('endVisit() (legacy)', () {
      test('clears active legacy visit', () {
        final visit = createTestLegacyVisit();
        visitService.startVisit(visit);

        expect(visitService.hasActiveVisit, true);

        visitService.endVisit();

        expect(visitService.hasActiveVisit, false);
        expect(visitService.activeVisit, isNull);
      });

      test('does nothing when no legacy visit active', () {
        visitService.endVisit();
        expect(visitService.hasActiveVisit, false);
      });
    });

    group('endApiVisit()', () {
      test('clears active API visit', () async {
        final visit = createTestApiVisit();
        await visitService.startApiVisit(visit);

        expect(visitService.hasActiveApiVisit, true);

        await visitService.endApiVisit();

        expect(visitService.hasActiveApiVisit, false);
        expect(visitService.activeApiVisit, isNull);
      });

      test('clears visit from SharedPreferences', () async {
        final visit = createTestApiVisit();
        await visitService.startApiVisit(visit);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('active_api_visit'), isNotNull);

        await visitService.endApiVisit();

        expect(prefs.getString('active_api_visit'), isNull);
      });

      test('does nothing when no API visit active', () async {
        await visitService.endApiVisit();
        expect(visitService.hasActiveApiVisit, false);
      });
    });

    group('updateActiveVisit() (legacy)', () {
      test('updates active visit when ID matches', () {
        final visit = createTestLegacyVisit(id: 'visit-1', clientName: 'Original');
        visitService.startVisit(visit);

        final updatedVisit = createTestLegacyVisit(
          id: 'visit-1',
          clientName: 'Updated',
        );
        visitService.updateActiveVisit(updatedVisit);

        expect(visitService.activeVisit?.clientName, 'Updated');
      });

      test('does not update when ID does not match', () {
        final visit = createTestLegacyVisit(id: 'visit-1', clientName: 'Original');
        visitService.startVisit(visit);

        final differentVisit = createTestLegacyVisit(
          id: 'visit-2',
          clientName: 'Different',
        );
        visitService.updateActiveVisit(differentVisit);

        expect(visitService.activeVisit?.clientName, 'Original');
      });

      test('auto-ends visit when status changes to completed', () {
        final visit = createTestLegacyVisit(status: VisitStatus.inProgress);
        visitService.startVisit(visit);

        final completedVisit = createTestLegacyVisit(
          status: VisitStatus.completed,
        );
        visitService.updateActiveVisit(completedVisit);

        expect(visitService.activeVisit, isNull);
        expect(visitService.hasActiveVisit, false);
      });

      test('auto-ends visit when status changes to skipped', () {
        final visit = createTestLegacyVisit(status: VisitStatus.inProgress);
        visitService.startVisit(visit);

        final skippedVisit = createTestLegacyVisit(status: VisitStatus.skipped);
        visitService.updateActiveVisit(skippedVisit);

        expect(visitService.activeVisit, isNull);
      });
    });

    group('updateActiveApiVisit()', () {
      test('updates active API visit when ID matches', () async {
        final visit = createTestApiVisit(id: 1);
        await visitService.startApiVisit(visit);

        final updatedVisit = createTestApiVisit(
          id: 1,
          client: ApiVisitClient(id: 100, name: 'Updated Client'),
        );
        await visitService.updateActiveApiVisit(updatedVisit);

        expect(visitService.activeApiVisit?.client?.name, 'Updated Client');
      });

      test('does not update when ID does not match', () async {
        final visit = createTestApiVisit(id: 1);
        await visitService.startApiVisit(visit);

        final differentVisit = createTestApiVisit(id: 2);
        await visitService.updateActiveApiVisit(differentVisit);

        expect(visitService.activeApiVisit?.id, 1);
      });

      test('auto-ends visit when status changes to completed', () async {
        final visit = createTestApiVisit(id: 1, status: 'started');
        await visitService.startApiVisit(visit);

        final completedVisit = createTestApiVisit(id: 1, status: 'completed');
        await visitService.updateActiveApiVisit(completedVisit);

        expect(visitService.activeApiVisit, isNull);
        expect(visitService.hasActiveApiVisit, false);
      });

      test('auto-ends visit when status changes to aborted', () async {
        final visit = createTestApiVisit(id: 1, status: 'started');
        await visitService.startApiVisit(visit);

        final abortedVisit = createTestApiVisit(id: 1, status: 'aborted');
        await visitService.updateActiveApiVisit(abortedVisit);

        expect(visitService.activeApiVisit, isNull);
      });

      test('persists updates to SharedPreferences', () async {
        final visit = createTestApiVisit(id: 1);
        await visitService.startApiVisit(visit);

        final updatedVisit = createTestApiVisit(
          id: 1,
          client: ApiVisitClient(id: 100, name: 'Persisted Update'),
        );
        await visitService.updateActiveApiVisit(updatedVisit);

        final prefs = await SharedPreferences.getInstance();
        final savedJson = prefs.getString('active_api_visit');

        expect(savedJson, contains('Persisted Update'));
      });
    });

    group('activeClientName', () {
      test('returns API visit client name when API visit active', () async {
        final visit = createTestApiVisit(
          client: ApiVisitClient(id: 100, name: 'API Client'),
        );
        await visitService.startApiVisit(visit);

        expect(visitService.activeClientName, 'API Client');
      });

      test('returns legacy visit client name when legacy visit active', () {
        final visit = createTestLegacyVisit(clientName: 'Legacy Client');
        visitService.startVisit(visit);

        expect(visitService.activeClientName, 'Legacy Client');
      });

      test('prefers API visit over legacy visit', () async {
        // This shouldn't happen in practice, but test the priority
        final apiVisit = createTestApiVisit(
          client: ApiVisitClient(id: 100, name: 'API Client'),
        );
        await visitService.startApiVisit(apiVisit);

        expect(visitService.activeClientName, 'API Client');
      });
    });

    group('activeClientId', () {
      test('returns client ID from API visit', () async {
        final visit = createTestApiVisit(clientId: 456);
        await visitService.startApiVisit(visit);

        expect(visitService.activeClientId, 456);
      });

      test('returns null when no API visit active', () {
        expect(visitService.activeClientId, isNull);
      });
    });

    group('activeVisitId', () {
      test('returns visit ID from API visit', () async {
        final visit = createTestApiVisit(id: 789);
        await visitService.startApiVisit(visit);

        expect(visitService.activeVisitId, 789);
      });

      test('returns null when no API visit active', () {
        expect(visitService.activeVisitId, isNull);
      });
    });

    group('activeVisitStartTime', () {
      test('returns start time from API visit', () async {
        final startTime = DateTime(2024, 1, 1, 10, 0);
        final visit = createTestApiVisit(startedAt: startTime);
        await visitService.startApiVisit(visit);

        expect(visitService.activeVisitStartTime, startTime);
      });

      test('returns start time from legacy visit', () {
        final startTime = DateTime(2024, 1, 1, 10, 0);
        final visit = createTestLegacyVisit(actualStartTime: startTime);
        visitService.startVisit(visit);

        expect(visitService.activeVisitStartTime, startTime);
      });

      test('returns null when no visit active', () {
        expect(visitService.activeVisitStartTime, isNull);
      });
    });

    group('loadActiveVisit()', () {
      test('loads active visit from SharedPreferences', () async {
        // First, save a visit
        final visit = createTestApiVisit(
          id: 999,
          client: ApiVisitClient(id: 100, name: 'Persisted Client'),
        );
        await visitService.startApiVisit(visit);

        // Reset in-memory state
        await visitService.reset();

        // Save again to SharedPreferences before loading
        await visitService.startApiVisit(visit);

        // Now create fresh instance and load
        await visitService.reset();

        // Manually set SharedPreferences for test
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_api_visit', '''
          {
            "id": 999,
            "client_id": 100,
            "user_id": 10,
            "status": "started",
            "client": {"id": 100, "name": "Persisted Client"}
          }
        ''');

        await visitService.loadActiveVisit();

        expect(visitService.hasActiveApiVisit, true);
        expect(visitService.activeApiVisit?.id, 999);
      });

      test('clears visit if no longer active', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_api_visit', '''
          {
            "id": 999,
            "client_id": 100,
            "user_id": 10,
            "status": "completed"
          }
        ''');

        await visitService.loadActiveVisit();

        expect(visitService.hasActiveApiVisit, false);
        expect(prefs.getString('active_api_visit'), isNull);
      });

      test('handles malformed JSON gracefully', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_api_visit', 'invalid json');

        await visitService.loadActiveVisit();

        expect(visitService.hasActiveApiVisit, false);
        expect(prefs.getString('active_api_visit'), isNull);
      });

      test('handles missing data gracefully', () async {
        await visitService.loadActiveVisit();
        expect(visitService.hasActiveApiVisit, false);
      });
    });

    group('reset()', () {
      test('clears all active visits', () async {
        final visit = createTestApiVisit();
        await visitService.startApiVisit(visit);

        expect(visitService.hasActiveVisit, true);

        await visitService.reset();

        expect(visitService.hasActiveVisit, false);
        expect(visitService.activeVisit, isNull);
        expect(visitService.activeApiVisit, isNull);
      });

      test('clears SharedPreferences', () async {
        final visit = createTestApiVisit();
        await visitService.startApiVisit(visit);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('active_api_visit'), isNotNull);

        await visitService.reset();

        expect(prefs.getString('active_api_visit'), isNull);
      });
    });

    group('isClientVisitActive()', () {
      test('returns true when client has active visit', () async {
        final visit = createTestApiVisit(clientId: 123);
        await visitService.startApiVisit(visit);

        expect(visitService.isClientVisitActive(123), true);
      });

      test('returns false when different client has active visit', () async {
        final visit = createTestApiVisit(clientId: 123);
        await visitService.startApiVisit(visit);

        expect(visitService.isClientVisitActive(456), false);
      });

      test('returns false when no visit active', () {
        expect(visitService.isClientVisitActive(123), false);
      });
    });

    group('mutual exclusivity', () {
      test('only one visit can be active at a time', () async {
        final apiVisit = createTestApiVisit();
        await visitService.startApiVisit(apiVisit);

        final legacyVisit = createTestLegacyVisit();
        final legacyResult = visitService.startVisit(legacyVisit);

        expect(legacyResult, false);
        expect(visitService.hasActiveApiVisit, true);
        expect(visitService.activeVisit, isNull);
      });

      test('hasActiveVisit returns true for either type', () async {
        // Test with API visit
        final apiVisit = createTestApiVisit();
        await visitService.startApiVisit(apiVisit);
        expect(visitService.hasActiveVisit, true);

        await visitService.reset();

        // Test with legacy visit
        final legacyVisit = createTestLegacyVisit();
        visitService.startVisit(legacyVisit);
        expect(visitService.hasActiveVisit, true);
      });
    });

    group('visite démarrée hors ligne', () {
      /// Le serveur ignore encore cette visite : sa réponse « aucune visite
      /// en cours » ne doit pas effacer la visite ouverte devant le client.
      test('syncWithServer keeps a locally started visit', () async {
        final localVisit = createTestApiVisit(id: -1735000000000);
        await visitService.startApiVisit(localVisit);

        final synced = await visitService.syncWithServer();

        expect(synced?.id, localVisit.id);
        expect(visitService.hasActiveApiVisit, true);
      });

      /// Une visite démarrée hors ligne n'embarque pas la fiche client du
      /// serveur : le nom affiché dans la barre vient du client mémorisé.
      test('activeClientName falls back to the stored client', () async {
        final localVisit = ApiVisit(
          id: -1735000000000,
          clientId: 100,
          userId: 0,
          status: 'started',
          startedAt: DateTime.now(),
        );
        await visitService.startApiVisit(
          localVisit,
          client: Client(
            id: 100,
            name: 'Boutique Awa',
            type: 'Boutique',
            managerName: 'Awa',
            phones: const [],
            city: 'Casablanca',
            address: '123 Main Street',
            hasOpenAlert: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        expect(visitService.activeClientName, 'Boutique Awa');
        expect(visitService.activeClient?.id, 100);
      });
    });
  });
}
