import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../network/supabase_client.dart';
import 'sync_service.dart';
import '../../features/cleaning_tasks/presentation/controllers/household_state_provider.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final bool isAwaitingEmailConfirmation;
  final String? userId;
  final String? email;
  final String? householdId;
  final String? householdName;
  final String? inviteCode;
  final String role; // 'parent' or 'child'
  final String name;
  final int pointsTotal;

  const AuthState({
    required this.isAuthenticated,
    this.isLoading = false,
    this.isAwaitingEmailConfirmation = false,
    this.userId,
    this.email,
    this.householdId,
    this.householdName,
    this.inviteCode,
    this.role = 'parent',
    this.name = '',
    this.pointsTotal = 0,
  });

  bool get isParent => role == 'parent' || role == 'admin';
  bool get isChild => role == 'child';

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    bool? isAwaitingEmailConfirmation,
    String? userId,
    String? email,
    String? householdId,
    String? householdName,
    String? inviteCode,
    String? role,
    String? name,
    int? pointsTotal,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      isAwaitingEmailConfirmation: isAwaitingEmailConfirmation ?? this.isAwaitingEmailConfirmation,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      householdId: householdId ?? this.householdId,
      householdName: householdName ?? this.householdName,
      inviteCode: inviteCode ?? this.inviteCode,
      role: role ?? this.role,
      name: name ?? this.name,
      pointsTotal: pointsTotal ?? this.pointsTotal,
    );
  }
}

class AuthService {
  final SupabaseClient? supabase;
  final Ref ref;

  AuthService(this.supabase, this.ref);

  /// Check current Supabase session; returns unauthenticated state if none found.
  AuthState getInitialState() {
    final session = supabase?.auth.currentSession;
    if (session != null && session.user.emailConfirmedAt != null) {
      final user = session.user;
      final metadata = user.userMetadata ?? {};
      final state = AuthState(
        isAuthenticated: true,
        userId: user.id,
        email: user.email,
        name: metadata['name'] as String? ?? user.email?.split('@').first ?? 'User',
        role: metadata['role'] as String? ?? 'parent',
        householdId: metadata['household_id'] as String?,
        inviteCode: metadata['invite_code'] as String?,
      );
      _syncToHouseholdState(state);
      _fetchLatestProfile(state);
      return state;
    }
    // No active session — require login
    return const AuthState(isAuthenticated: false);
  }

  /// Sign in with email and password
  Future<AuthState> signIn({required String email, required String password}) async {
    final client = supabase;
    if (client == null) {
      throw Exception('No connection available. Please check your internet connection.');
    }

    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw Exception('Sign in failed. Please check your credentials.');
      }

      // Check if email confirmed
      if (user.emailConfirmedAt == null && response.session == null) {
        return AuthState(
          isAuthenticated: false,
          isAwaitingEmailConfirmation: true,
          email: email.trim(),
        );
      }

      final metadata = user.userMetadata ?? {};
      var state = AuthState(
        isAuthenticated: true,
        userId: user.id,
        email: user.email,
        name: metadata['name'] as String? ?? email.split('@').first,
        role: metadata['role'] as String? ?? 'parent',
        householdId: metadata['household_id'] as String?,
        inviteCode: metadata['invite_code'] as String?,
      );

      // Fetch fresh profile & household details from DB
      state = await _fetchProfileAndHousehold(state);
      _syncToHouseholdState(state);
      return state;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('email not confirmed')) {
        return AuthState(
          isAuthenticated: false,
          isAwaitingEmailConfirmation: true,
          email: email.trim(),
        );
      }
      throw Exception(e.message);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Sign up with role and household join or creation
  Future<AuthState> signUp({
    required String email,
    required String password,
    required String name,
    required String role, // 'parent' or 'child'
    required bool createNewHousehold,
    String? householdName,
    String? inviteCode,
  }) async {
    final client = supabase;
    if (client == null) {
      throw Exception('No connection available. Please check your internet connection.');
    }

    final trimmedEmail = email.trim();
    final trimmedName = name.trim();

    String targetHouseholdId;
    String effectiveInviteCode;
    String effectiveHouseholdName = householdName?.trim().isNotEmpty == true
        ? householdName!.trim()
        : '$trimmedName\'s Home';

    if (createNewHousehold) {
      // Parent creates a brand-new household
      final newCode = generateInviteCode();
      final newHhId = const Uuid().v4();
      await client.from('Household').insert({
        'id': newHhId,
        'name': effectiveHouseholdName,
        'invite_code': newCode,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      targetHouseholdId = newHhId;
      effectiveInviteCode = newCode;
    } else {
      // Child or second parent joins via invite code
      if (inviteCode == null || inviteCode.trim().isEmpty) {
        throw Exception('Please enter an invite code to join a household.');
      }
      final code = inviteCode.trim().toUpperCase();
      final existing = await client
          .from('Household')
          .select('id, name, invite_code')
          .eq('invite_code', code)
          .maybeSingle();

      if (existing == null) {
        throw Exception('Invalid invite code. Please check with your household owner.');
      }
      targetHouseholdId = existing['id'] as String;
      effectiveInviteCode = existing['invite_code'] as String;
      effectiveHouseholdName = existing['name'] as String? ?? 'Family Home';
    }

    try {
      final authRes = await client.auth.signUp(
        email: trimmedEmail,
        password: password,
        data: {
          'name': trimmedName,
          'role': role,
          'household_id': targetHouseholdId,
          'invite_code': effectiveInviteCode,
        },
      );

      final user = authRes.user;
      if (user == null) {
        throw Exception('Account creation failed. Please try again.');
      }

      // Check if user already existed (Supabase returns empty identities list for duplicate registrations)
      if (user.identities != null && user.identities!.isEmpty) {
        throw Exception('This email address is already registered. Please sign in instead.');
      }

      // Register in public User table
      await client.from('User').upsert({
        'id': user.id,
        'household_id': targetHouseholdId,
        'name': trimmedName,
        'email': trimmedEmail,
        'role': role == 'child' ? 'child' : 'admin',
        'points_total': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // If email confirmation is required (session is null)
      if (authRes.session == null) {
        return AuthState(
          isAuthenticated: false,
          isAwaitingEmailConfirmation: true,
          email: trimmedEmail,
          userId: user.id,
          name: trimmedName,
          role: role,
          householdId: targetHouseholdId,
          householdName: effectiveHouseholdName,
          inviteCode: effectiveInviteCode,
        );
      }

      final state = AuthState(
        isAuthenticated: true,
        userId: user.id,
        email: user.email,
        name: trimmedName,
        role: role,
        householdId: targetHouseholdId,
        householdName: effectiveHouseholdName,
        inviteCode: effectiveInviteCode,
      );
      _syncToHouseholdState(state);
      return state;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('already registered') ||
          e.message.toLowerCase().contains('already exists')) {
        throw Exception('This email address is already registered. Please sign in instead.');
      }
      throw Exception(e.message);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Resend confirmation email
  Future<void> resendConfirmationEmail(String email) async {
    final client = supabase;
    if (client == null) throw Exception('No connection available');
    await client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
    );
  }

  /// Change password for authenticated user
  Future<void> changePassword(String newPassword) async {
    final client = supabase;
    if (client == null) throw Exception('No connection available');
    await client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Delete own account (removes from public.User and auth.users)
  Future<void> deleteAccount() async {
    final client = supabase;
    if (client == null) throw Exception('No connection available');
    try {
      await client.rpc('delete_own_user');
    } catch (_) {
      // Fallback: delete row in public.User directly
      final currentUid = client.auth.currentUser?.id;
      if (currentUid != null) {
        await client.from('User').delete().eq('id', currentUid);
      }
    }
    await signOut();
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await supabase?.auth.signOut();
    } catch (_) {}
    ref.read(currentUserProvider.notifier).clear();
    ref.read(householdMembersProvider.notifier).setMembers([]);
    try {
      await ref.read(syncServiceProvider).clearAllLocalData();
    } catch (_) {}
  }

  void _syncToHouseholdState(AuthState state) {
    ref.read(currentUserProvider.notifier).setUser(
          FamilyMember(
            id: state.userId ?? '',
            name: state.name,
            role: state.role,
            points: state.pointsTotal,
            avatar: state.isParent ? '👩‍💼' : '👦',
            email: state.email ?? '',
          ),
        );
    if (state.householdId != null && state.householdId!.isNotEmpty) {
      loadHouseholdMembers(state.householdId!);
    }
  }

  Future<AuthState> _fetchProfileAndHousehold(AuthState state) async {
    final client = supabase;
    if (client == null || state.userId == null) return state;
    try {
      final userRow = await client
          .from('User')
          .select('household_id, name, role, points_total')
          .eq('id', state.userId!)
          .maybeSingle();

      String? hhId = state.householdId;
      String name = state.name;
      String role = state.role;
      int points = state.pointsTotal;

      if (userRow != null) {
        hhId = userRow['household_id'] as String? ?? hhId;
        name = userRow['name'] as String? ?? name;
        role = (userRow['role'] as String? ?? 'admin') == 'child' ? 'child' : 'parent';
        points = (userRow['points_total'] as num?)?.toInt() ?? points;
      }

      String? hhName = state.householdName;
      String? inviteCode = state.inviteCode;
      if (hhId != null) {
        final hhRow = await client
            .from('Household')
            .select('name, invite_code')
            .eq('id', hhId)
            .maybeSingle();
        if (hhRow != null) {
          hhName = hhRow['name'] as String? ?? hhName;
          inviteCode = hhRow['invite_code'] as String? ?? inviteCode;
        }
      }

      return state.copyWith(
        householdId: hhId,
        householdName: hhName,
        inviteCode: inviteCode,
        name: name,
        role: role,
        pointsTotal: points,
      );
    } catch (_) {
      return state;
    }
  }

  Future<void> _fetchLatestProfile(AuthState state) async {
    final updated = await _fetchProfileAndHousehold(state);
    _syncToHouseholdState(updated);
  }

  Future<void> loadHouseholdMembers(String householdId) async {
    final client = supabase;
    if (client == null) return;
    try {
      final rows = await client
          .from('User')
          .select('id, name, email, role, avatar_url, points_total')
          .eq('household_id', householdId);

      final members = (rows as List).map((r) {
        final role = (r['role'] as String? ?? 'admin') == 'child' ? 'child' : 'parent';
        return FamilyMember(
          id: r['id'] as String,
          name: r['name'] as String? ?? 'Family Member',
          role: role,
          points: (r['points_total'] as num?)?.toInt() ?? 0,
          avatar: r['avatar_url'] as String? ?? (role == 'parent' ? '👩‍💼' : '👦'),
          email: r['email'] as String? ?? '',
        );
      }).toList();

      ref.read(householdMembersProvider.notifier).setMembers(members);

      // If current user is in this list, sync their points to currentUserProvider
      final current = ref.read(currentUserProvider);
      if (current != null) {
        final me = members.cast<FamilyMember?>().firstWhere(
          (m) => m?.id == current.id || (m?.email.isNotEmpty == true && m?.email == current.email),
          orElse: () => null,
        );
        if (me != null) {
          ref.read(currentUserProvider.notifier).setUser(me);
        }
      }
    } catch (_) {}
  }

  /// Generates a human-friendly unique invite code, e.g. "SPATIO-4892"
  static String generateInviteCode() {
    final random = Random();
    final digits = 1000 + random.nextInt(9000);
    return 'SPATIO-$digits';
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthService _service;
  StreamSubscription? _supabaseAuthSub;

  @override
  AuthState build() {
    final client = ref.watch(supabaseClientProvider);
    _service = AuthService(client, ref);

    // Listen to Supabase auth state changes for seamless session persistence & multi-device sync
    if (client != null) {
      _supabaseAuthSub?.cancel();
      _supabaseAuthSub = client.auth.onAuthStateChange.listen((data) async {
        final session = data.session;
        if (session != null && session.user.emailConfirmedAt != null) {
          final user = session.user;
          final metadata = user.userMetadata ?? {};
          final baseState = AuthState(
            isAuthenticated: true,
            userId: user.id,
            email: user.email,
            name: metadata['name'] as String? ?? user.email?.split('@').first ?? 'User',
            role: metadata['role'] as String? ?? 'parent',
            householdId: metadata['household_id'] as String?,
            inviteCode: metadata['invite_code'] as String?,
          );
          final fullState = await _service._fetchProfileAndHousehold(baseState);
          _service._syncToHouseholdState(fullState);
          state = fullState;
        } else if (data.event == AuthChangeEvent.signedOut) {
          state = const AuthState(isAuthenticated: false);
        }
      });
    }

    ref.onDispose(() {
      _supabaseAuthSub?.cancel();
    });

    return _service.getInitialState();
  }

  Future<void> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true);
    try {
      final newState = await _service.signIn(email: email, password: password);
      state = newState;
    } finally {
      if (state.isLoading) state = state.copyWith(isLoading: false);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    required bool createNewHousehold,
    String? householdName,
    String? inviteCode,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final newState = await _service.signUp(
        email: email,
        password: password,
        name: name,
        role: role,
        createNewHousehold: createNewHousehold,
        householdName: householdName,
        inviteCode: inviteCode,
      );
      state = newState;
    } finally {
      if (state.isLoading) state = state.copyWith(isLoading: false);
    }
  }

  Future<void> resendConfirmationEmail(String email) async {
    await _service.resendConfirmationEmail(email);
  }

  Future<void> changePassword(String newPassword) async {
    await _service.changePassword(newPassword);
  }

  Future<void> deleteAccount() async {
    await _service.deleteAccount();
    state = const AuthState(isAuthenticated: false);
  }

  Future<void> signOut() async {
    await _service.signOut();
    state = const AuthState(isAuthenticated: false);
  }

  Future<void> refreshHouseholdMembers() async {
    if (state.householdId != null && state.householdId!.isNotEmpty) {
      await _service.loadHouseholdMembers(state.householdId!);
    }
  }

  void cancelAwaitingEmailConfirmation() {
    state = const AuthState(isAuthenticated: false);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
