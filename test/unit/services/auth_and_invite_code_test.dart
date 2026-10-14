import 'package:flutter_test/flutter_test.dart';
import 'package:spatio_cleaning/core/services/auth_service.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/presentation/controllers/household_state_provider.dart';

void main() {
  group('Invite Code & Household Membership Status Tests', () {
    test('generateInviteCode creates secure SPATIO-XXXX-XXXX format with valid base32 charset', () {
      final code = AuthService.generateInviteCode();
      expect(code.startsWith('SPATIO-'), isTrue);
      expect(code.length, equals(16)); // 'SPATIO-' (7) + 4 + '-' (1) + 4 = 16
      
      final parts = code.split('-');
      expect(parts.length, equals(3));
      expect(parts[0], equals('SPATIO'));
      expect(parts[1].length, equals(4));
      expect(parts[2].length, equals(4));

      // Allowed unambiguous chars: '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'
      final validChars = RegExp(r'^[2-9A-HJ-NP-Z]{4}$');
      expect(validChars.hasMatch(parts[1]), isTrue, reason: 'Part 1 contains invalid characters');
      expect(validChars.hasMatch(parts[2]), isTrue, reason: 'Part 2 contains invalid characters');
    });

    test('generateInviteCode produces unique codes without collisions', () {
      final generated = <String>{};
      for (int i = 0; i < 500; i++) {
        final code = AuthService.generateInviteCode();
        expect(generated.contains(code), isFalse, reason: 'Duplicate code generated: $code');
        generated.add(code);
      }
      expect(generated.length, equals(500));
    });

    test('AuthState pending membership correctly computes isPendingApproval', () {
      const activeState = AuthState(
        isAuthenticated: true,
        membershipStatus: 'active',
      );
      expect(activeState.isPendingApproval, isFalse);

      const pendingState = AuthState(
        isAuthenticated: true,
        membershipStatus: 'pending',
      );
      expect(pendingState.isPendingApproval, isTrue);

      final updatedState = pendingState.copyWith(membershipStatus: 'active');
      expect(updatedState.isPendingApproval, isFalse);
    });

    test('FamilyMember membershipStatus getters and immutability', () {
      const member = FamilyMember(
        id: 'user-1',
        name: 'Little Timmy',
        role: 'child',
        avatar: '👦',
        email: 'timmy@family.com',
        membershipStatus: 'pending',
      );

      expect(member.isPending, isTrue);
      expect(member.isActive, isFalse);
      expect(member.isRejected, isFalse);

      final approved = member.copyWith(membershipStatus: 'active');
      expect(approved.isPending, isFalse);
      expect(approved.isActive, isTrue);

      final rejected = member.copyWith(membershipStatus: 'rejected');
      expect(rejected.isPending, isFalse);
      expect(rejected.isActive, isFalse);
      expect(rejected.isRejected, isTrue);
    });
  });
}
