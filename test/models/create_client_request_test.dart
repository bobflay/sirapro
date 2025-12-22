import 'package:flutter_test/flutter_test.dart';
import 'package:sirapro/models/create_client_request.dart';

void main() {
  group('CreateClientRequest', () {
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

    group('validate()', () {
      test('returns empty list for valid request', () {
        final request = createValidRequest();
        final errors = request.validate();
        expect(errors, isEmpty);
      });

      group('code validation', () {
        test('returns error when code is empty', () {
          final request = createValidRequest(code: '');
          final errors = request.validate();
          expect(errors, contains('Le code client est requis'));
        });

        test('returns error when code exceeds 255 characters', () {
          final request = createValidRequest(code: 'a' * 256);
          final errors = request.validate();
          expect(
              errors, contains('Le code client ne peut pas dépasser 255 caractères'));
        });

        test('accepts code at exactly 255 characters', () {
          final request = createValidRequest(code: 'a' * 255);
          final errors = request.validate();
          expect(errors.where((e) => e.contains('code')), isEmpty);
        });
      });

      group('name validation', () {
        test('returns error when name is empty', () {
          final request = createValidRequest(name: '');
          final errors = request.validate();
          expect(errors, contains('Le nom du client est requis'));
        });

        test('returns error when name exceeds 255 characters', () {
          final request = createValidRequest(name: 'a' * 256);
          final errors = request.validate();
          expect(errors, contains('Le nom ne peut pas dépasser 255 caractères'));
        });

        test('accepts name at exactly 255 characters', () {
          final request = createValidRequest(name: 'a' * 255);
          final errors = request.validate();
          expect(errors.where((e) => e.contains('nom')), isEmpty);
        });
      });

      group('type validation', () {
        test('accepts valid type: Boutique', () {
          final request = createValidRequest(type: 'Boutique');
          final errors = request.validate();
          expect(errors.where((e) => e.contains('Type')), isEmpty);
        });

        test('accepts valid type: Supermarché', () {
          final request = createValidRequest(type: 'Supermarché');
          final errors = request.validate();
          expect(errors.where((e) => e.contains('Type')), isEmpty);
        });

        test('accepts valid type: Demi-grossiste', () {
          final request = createValidRequest(type: 'Demi-grossiste');
          final errors = request.validate();
          expect(errors.where((e) => e.contains('Type')), isEmpty);
        });

        test('accepts valid type: Grossiste', () {
          final request = createValidRequest(type: 'Grossiste');
          final errors = request.validate();
          expect(errors.where((e) => e.contains('Type')), isEmpty);
        });

        test('accepts valid type: Distributeur', () {
          final request = createValidRequest(type: 'Distributeur');
          final errors = request.validate();
          expect(errors.where((e) => e.contains('Type')), isEmpty);
        });

        test('accepts valid type: Autre', () {
          final request = createValidRequest(type: 'Autre');
          final errors = request.validate();
          expect(errors.where((e) => e.contains('Type')), isEmpty);
        });

        test('returns error for invalid type', () {
          final request = createValidRequest(type: 'InvalidType');
          final errors = request.validate();
          expect(errors, contains('Type de client invalide'));
        });

        test('returns error for empty type', () {
          final request = createValidRequest(type: '');
          final errors = request.validate();
          expect(errors, contains('Type de client invalide'));
        });
      });

      group('potential validation', () {
        test('accepts valid potential: A', () {
          final request = createValidRequest(potential: 'A');
          final errors = request.validate();
          expect(errors.where((e) => e.contains('Potentiel')), isEmpty);
        });

        test('accepts valid potential: B', () {
          final request = createValidRequest(potential: 'B');
          final errors = request.validate();
          expect(errors.where((e) => e.contains('Potentiel')), isEmpty);
        });

        test('accepts valid potential: C', () {
          final request = createValidRequest(potential: 'C');
          final errors = request.validate();
          expect(errors.where((e) => e.contains('Potentiel')), isEmpty);
        });

        test('returns error for invalid potential', () {
          final request = createValidRequest(potential: 'D');
          final errors = request.validate();
          expect(errors, contains('Potentiel invalide'));
        });

        test('returns error for lowercase potential', () {
          final request = createValidRequest(potential: 'a');
          final errors = request.validate();
          expect(errors, contains('Potentiel invalide'));
        });
      });

      group('phone validation', () {
        test('returns error when phone is empty', () {
          final request = createValidRequest(phone: '');
          final errors = request.validate();
          expect(errors, contains('Le numéro de téléphone est requis'));
        });

        test('returns error when phone exceeds 255 characters', () {
          final request = createValidRequest(phone: '0' * 256);
          final errors = request.validate();
          expect(errors,
              contains('Le numéro de téléphone ne peut pas dépasser 255 caractères'));
        });
      });

      group('city validation', () {
        test('returns error when city is empty', () {
          final request = createValidRequest(city: '');
          final errors = request.validate();
          expect(errors, contains('La ville est requise'));
        });

        test('returns error when city exceeds 255 characters', () {
          final request = createValidRequest(city: 'a' * 256);
          final errors = request.validate();
          expect(errors, contains('La ville ne peut pas dépasser 255 caractères'));
        });
      });

      group('latitude validation', () {
        test('accepts latitude at minimum bound (-90)', () {
          final request = createValidRequest(latitude: -90.0);
          final errors = request.validate();
          expect(errors.where((e) => e.contains('Latitude')), isEmpty);
        });

        test('accepts latitude at maximum bound (90)', () {
          final request = createValidRequest(latitude: 90.0);
          final errors = request.validate();
          expect(errors.where((e) => e.contains('Latitude')), isEmpty);
        });

        test('accepts latitude at zero', () {
          final request = createValidRequest(latitude: 0.0);
          final errors = request.validate();
          expect(errors.where((e) => e.contains('Latitude')), isEmpty);
        });

        test('returns error when latitude is below -90', () {
          final request = createValidRequest(latitude: -90.1);
          final errors = request.validate();
          expect(errors, contains('Latitude invalide (doit être entre -90 et 90)'));
        });

        test('returns error when latitude is above 90', () {
          final request = createValidRequest(latitude: 90.1);
          final errors = request.validate();
          expect(errors, contains('Latitude invalide (doit être entre -90 et 90)'));
        });
      });

      group('longitude validation', () {
        test('accepts longitude at minimum bound (-180)', () {
          final request = createValidRequest(longitude: -180.0);
          final errors = request.validate();
          expect(errors.where((e) => e.contains('Longitude')), isEmpty);
        });

        test('accepts longitude at maximum bound (180)', () {
          final request = createValidRequest(longitude: 180.0);
          final errors = request.validate();
          expect(errors.where((e) => e.contains('Longitude')), isEmpty);
        });

        test('accepts longitude at zero', () {
          final request = createValidRequest(longitude: 0.0);
          final errors = request.validate();
          expect(errors.where((e) => e.contains('Longitude')), isEmpty);
        });

        test('returns error when longitude is below -180', () {
          final request = createValidRequest(longitude: -180.1);
          final errors = request.validate();
          expect(
              errors, contains('Longitude invalide (doit être entre -180 et 180)'));
        });

        test('returns error when longitude is above 180', () {
          final request = createValidRequest(longitude: 180.1);
          final errors = request.validate();
          expect(
              errors, contains('Longitude invalide (doit être entre -180 et 180)'));
        });
      });

      group('visitFrequency validation', () {
        test('accepts valid frequency: weekly', () {
          final request = createValidRequest(visitFrequency: 'weekly');
          final errors = request.validate();
          expect(errors.where((e) => e.contains('Fréquence')), isEmpty);
        });

        test('accepts valid frequency: biweekly', () {
          final request = createValidRequest(visitFrequency: 'biweekly');
          final errors = request.validate();
          expect(errors.where((e) => e.contains('Fréquence')), isEmpty);
        });

        test('accepts valid frequency: monthly', () {
          final request = createValidRequest(visitFrequency: 'monthly');
          final errors = request.validate();
          expect(errors.where((e) => e.contains('Fréquence')), isEmpty);
        });

        test('accepts valid frequency: other', () {
          final request = createValidRequest(visitFrequency: 'other');
          final errors = request.validate();
          expect(errors.where((e) => e.contains('Fréquence')), isEmpty);
        });

        test('returns error for invalid frequency', () {
          final request = createValidRequest(visitFrequency: 'daily');
          final errors = request.validate();
          expect(errors, contains('Fréquence de visite invalide'));
        });
      });

      group('email validation', () {
        test('accepts null email', () {
          final request = createValidRequest(email: null);
          final errors = request.validate();
          expect(errors.where((e) => e.contains('email')), isEmpty);
        });

        test('accepts empty email', () {
          final request = createValidRequest(email: '');
          final errors = request.validate();
          expect(errors.where((e) => e.contains('email')), isEmpty);
        });

        test('accepts valid email format', () {
          final request = createValidRequest(email: 'test@example.com');
          final errors = request.validate();
          expect(errors.where((e) => e.contains('email')), isEmpty);
        });

        test('accepts email with subdomain', () {
          final request = createValidRequest(email: 'test@mail.example.com');
          final errors = request.validate();
          expect(errors.where((e) => e.contains('email')), isEmpty);
        });

        test('accepts email with plus sign', () {
          final request = createValidRequest(email: 'test+tag@example.com');
          final errors = request.validate();
          expect(errors.where((e) => e.contains('email')), isEmpty);
        });

        test('returns error for invalid email: missing @', () {
          final request = createValidRequest(email: 'testexample.com');
          final errors = request.validate();
          expect(errors, contains("Format d'email invalide"));
        });

        test('returns error for invalid email: missing domain', () {
          final request = createValidRequest(email: 'test@');
          final errors = request.validate();
          expect(errors, contains("Format d'email invalide"));
        });

        test('returns error for invalid email: missing TLD', () {
          final request = createValidRequest(email: 'test@example');
          final errors = request.validate();
          expect(errors, contains("Format d'email invalide"));
        });

        test('returns error for invalid email: spaces', () {
          final request = createValidRequest(email: 'test @example.com');
          final errors = request.validate();
          expect(errors, contains("Format d'email invalide"));
        });
      });

      group('multiple validation errors', () {
        test('returns all errors when multiple fields are invalid', () {
          final request = CreateClientRequest(
            code: '',
            name: '',
            type: 'Invalid',
            potential: 'X',
            baseCommercialeId: 1,
            zoneId: 1,
            phone: '',
            city: '',
            latitude: 100.0,
            longitude: 200.0,
            visitFrequency: 'invalid',
            email: 'invalid-email',
          );
          final errors = request.validate();

          expect(errors.length, greaterThanOrEqualTo(9));
          expect(errors, contains('Le code client est requis'));
          expect(errors, contains('Le nom du client est requis'));
          expect(errors, contains('Type de client invalide'));
          expect(errors, contains('Potentiel invalide'));
          expect(errors, contains('Le numéro de téléphone est requis'));
          expect(errors, contains('La ville est requise'));
          expect(errors, contains('Latitude invalide (doit être entre -90 et 90)'));
          expect(
              errors, contains('Longitude invalide (doit être entre -180 et 180)'));
          expect(errors, contains('Fréquence de visite invalide'));
          expect(errors, contains("Format d'email invalide"));
        });
      });
    });

    group('toJson()', () {
      test('serializes required fields correctly', () {
        final request = createValidRequest();
        final json = request.toJson();

        expect(json['code'], 'CLI001');
        expect(json['name'], 'Test Boutique');
        expect(json['type'], 'Boutique');
        expect(json['potential'], 'A');
        expect(json['base_commerciale_id'], 1);
        expect(json['zone_id'], 1);
        expect(json['phone'], '+212600000000');
        expect(json['city'], 'Casablanca');
        expect(json['latitude'], 33.5731);
        expect(json['longitude'], -7.5898);
        expect(json['visit_frequency'], 'weekly');
      });

      test('excludes null optional fields', () {
        final request = createValidRequest();
        final json = request.toJson();

        expect(json.containsKey('manager_name'), isFalse);
        expect(json.containsKey('whatsapp'), isFalse);
        expect(json.containsKey('email'), isFalse);
        expect(json.containsKey('district'), isFalse);
        expect(json.containsKey('address_description'), isFalse);
        expect(json.containsKey('is_active'), isFalse);
      });

      test('excludes empty string optional fields', () {
        final request = createValidRequest(
          managerName: '',
          whatsapp: '',
          email: '',
          district: '',
          addressDescription: '',
        );
        final json = request.toJson();

        expect(json.containsKey('manager_name'), isFalse);
        expect(json.containsKey('whatsapp'), isFalse);
        expect(json.containsKey('email'), isFalse);
        expect(json.containsKey('district'), isFalse);
        expect(json.containsKey('address_description'), isFalse);
      });

      test('includes non-empty optional fields', () {
        final request = createValidRequest(
          managerName: 'John Doe',
          whatsapp: '+212611111111',
          email: 'john@example.com',
          district: 'Maarif',
          addressDescription: 'Near the market',
          isActive: true,
        );
        final json = request.toJson();

        expect(json['manager_name'], 'John Doe');
        expect(json['whatsapp'], '+212611111111');
        expect(json['email'], 'john@example.com');
        expect(json['district'], 'Maarif');
        expect(json['address_description'], 'Near the market');
        expect(json['is_active'], true);
      });

      test('includes isActive when false', () {
        final request = createValidRequest(isActive: false);
        final json = request.toJson();

        expect(json['is_active'], false);
      });
    });

    group('frequencyToApiValue()', () {
      test('maps Hebdomadaire to weekly', () {
        expect(CreateClientRequest.frequencyToApiValue('Hebdomadaire'), 'weekly');
      });

      test('maps Bimensuelle to biweekly', () {
        expect(CreateClientRequest.frequencyToApiValue('Bimensuelle'), 'biweekly');
      });

      test('maps Mensuelle to monthly', () {
        expect(CreateClientRequest.frequencyToApiValue('Mensuelle'), 'monthly');
      });

      test('maps Autre to other', () {
        expect(CreateClientRequest.frequencyToApiValue('Autre'), 'other');
      });

      test('maps unknown value to other', () {
        expect(CreateClientRequest.frequencyToApiValue('Unknown'), 'other');
        expect(CreateClientRequest.frequencyToApiValue(''), 'other');
      });
    });

    group('apiValueToFrequency()', () {
      test('maps weekly to Hebdomadaire', () {
        expect(CreateClientRequest.apiValueToFrequency('weekly'), 'Hebdomadaire');
      });

      test('maps biweekly to Bimensuelle', () {
        expect(CreateClientRequest.apiValueToFrequency('biweekly'), 'Bimensuelle');
      });

      test('maps monthly to Mensuelle', () {
        expect(CreateClientRequest.apiValueToFrequency('monthly'), 'Mensuelle');
      });

      test('maps other to Autre', () {
        expect(CreateClientRequest.apiValueToFrequency('other'), 'Autre');
      });

      test('maps unknown value to Autre', () {
        expect(CreateClientRequest.apiValueToFrequency('unknown'), 'Autre');
        expect(CreateClientRequest.apiValueToFrequency(''), 'Autre');
      });
    });

    group('toString()', () {
      test('returns readable string representation', () {
        final request = createValidRequest(
          code: 'CLI001',
          name: 'Test Boutique',
          type: 'Boutique',
        );
        expect(
          request.toString(),
          'CreateClientRequest(code: CLI001, name: Test Boutique, type: Boutique)',
        );
      });
    });
  });
}
