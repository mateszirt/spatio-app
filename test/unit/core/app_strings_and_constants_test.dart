import 'package:flutter_test/flutter_test.dart';
import 'package:spatio_cleaning/core/constants/app_constants.dart';
import 'package:spatio_cleaning/core/constants/app_strings.dart';
import 'package:spatio_cleaning/core/errors/exceptions.dart';
import 'package:spatio_cleaning/core/utils/id_generator.dart';

void main() {
  group('AppStrings, AppConstants, Exceptions and IdGenerator Tests', () {
    test('AppConstants definitions', () {
      expect(AppConstants.appName, equals('Spatio'));
      expect(AppConstants.supabaseUrl, isNotEmpty);
      expect(AppConstants.supabaseAnonKey, isNotEmpty);
      expect(AppConstants.dbName, equals('spatio_app.sqlite'));
    });

    test('AppStrings.floorLabel ordinal formatting edge cases', () {
      expect(AppStrings.floorLabel(-1), equals('Ground Floor'));
      expect(AppStrings.floorLabel(0), equals('Ground Floor'));
      expect(AppStrings.floorLabel(1), equals('Ground Floor'));

      expect(AppStrings.floorLabel(2), equals('1st Floor'));
      expect(AppStrings.floorLabel(3), equals('2nd Floor'));
      expect(AppStrings.floorLabel(4), equals('3rd Floor'));
      expect(AppStrings.floorLabel(5), equals('4th Floor'));

      // 11th, 12th, 13th exception rules
      expect(AppStrings.floorLabel(11), equals('10th Floor'));
      expect(AppStrings.floorLabel(12), equals('11th Floor'));
      expect(AppStrings.floorLabel(13), equals('12th Floor'));
      expect(AppStrings.floorLabel(14), equals('13th Floor'));
      expect(AppStrings.floorLabel(15), equals('14th Floor'));

      // 21st, 22nd, 23rd
      expect(AppStrings.floorLabel(22), equals('21st Floor'));
      expect(AppStrings.floorLabel(23), equals('22nd Floor'));
      expect(AppStrings.floorLabel(24), equals('23rd Floor'));
      expect(AppStrings.floorLabel(25), equals('24th Floor'));
    });

    test('AppExceptions custom messages and toString', () {
      const serverErr = ServerException();
      expect(serverErr.message, equals('Szerver hiba történt'));
      expect(serverErr.toString(), equals('Szerver hiba történt'));

      const serverErrCustom = ServerException('HTTP 500: Gateway Timeout');
      expect(serverErrCustom.message, equals('HTTP 500: Gateway Timeout'));
      expect(serverErrCustom.toString(), equals('HTTP 500: Gateway Timeout'));

      const cacheErr = CacheException();
      expect(cacheErr.message, equals('Helyi adatbázis hiba történt'));
      expect(cacheErr.toString(), equals('Helyi adatbázis hiba történt'));

      const networkErr = NetworkException('No WiFi connection');
      expect(networkErr.message, equals('No WiFi connection'));
      expect(networkErr.toString(), equals('No WiFi connection'));
    });

    test('generateUuid produces RFC 4122 v4 compliant unique UUIDs', () {
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );

      final generatedSet = <String>{};
      for (int i = 0; i < 500; i++) {
        final id = generateUuid();
        expect(uuidRegex.hasMatch(id), isTrue, reason: '$id is not a valid v4 UUID');
        expect(generatedSet.contains(id), isFalse, reason: 'Collision detected on $id');
        generatedSet.add(id);
      }
      expect(generatedSet.length, equals(500));
    });
  });
}
