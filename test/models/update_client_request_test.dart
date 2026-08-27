import 'package:flutter_test/flutter_test.dart';
import 'package:sirapro/models/client.dart';
import 'package:sirapro/models/update_client_request.dart';

void main() {
  group('UpdateClientRequest', () {
    group('type validation', () {
      /// La fiche client propose les mêmes types que la création : modifier
      /// un PDV vers l'un d'eux ne doit jamais être refusé localement.
      test('accepts every type offered by the client form', () {
        for (final type in Client.types) {
          final errors = UpdateClientRequest(type: type).validate();
          expect(errors.where((e) => e.contains('Type')), isEmpty,
              reason: 'type refusé : $type');
        }
      });

      test('returns error for an unknown type', () {
        final errors = UpdateClientRequest(type: 'InvalidType').validate();
        expect(errors, contains('Type de client invalide'));
      });

      test('ignores the type when it is not being updated', () {
        final errors = UpdateClientRequest(name: 'Boutique Awa').validate();
        expect(errors.where((e) => e.contains('Type')), isEmpty);
      });
    });
  });
}
