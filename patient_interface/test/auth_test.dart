import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_interface/app_error.dart';
import 'package:patient_interface/models.dart';

void main() {
  group('AppException.of', () {
    test('wrong email or password all give the same message', () {
      for (final code in [
        'invalid-credential',
        'wrong-password',
        'user-not-found',
        'invalid-email',
      ]) {
        expect(
          AppException.of(FirebaseAuthException(code: code)).key,
          'err_cred',
          reason: code,
        );
      }
    });

    test('known Firebase codes map to their text keys', () {
      expect(
        AppException.of(FirebaseAuthException(code: 'email-already-in-use')).key,
        'err_used',
      );
      expect(
        AppException.of(FirebaseAuthException(code: 'too-many-requests')).key,
        'err_many',
      );
      final offline = AppException.of(
        FirebaseAuthException(code: 'network-request-failed'),
      );
      expect(offline.key, 'error_network');
      expect(offline.isNetwork, isTrue);
    });

    test('anything unknown is a generic error; an AppException is kept', () {
      expect(AppException.of(StateError('x')).key, 'error_generic');
      const own = AppException('err_link_taken');
      expect(identical(AppException.of(own), own), isTrue);
    });
  });

  group('AppUser.fromDoc', () {
    test('reads a profile written at sign-up', () {
      final u = AppUser.fromDoc('uid1', {
        'role': 'patient',
        'email': 'omar@example.com',
        'fullName': ' Omar Haddad ',
        'phone': '0599123456',
        'diabetesType': 'type2',
        'dateOfBirth': '1990-05-17',
      });
      expect(u.id, 'uid1');
      expect(u.fullName, 'Omar Haddad');
      expect(u.diabetesType, 'type2');
      expect(u.dateOfBirth, DateTime(1990, 5, 17));
    });

    test('empty text means "not set"', () {
      final u = AppUser.fromDoc('uid2', {
        'role': 'patient',
        'email': 'a@b.co',
        'fullName': '',
        'phone': '',
        'diabetesType': '',
        'dateOfBirth': '',
      });
      expect(u.phone, isNull);
      expect(u.diabetesType, isNull);
      expect(u.dateOfBirth, isNull);
    });
  });
}
