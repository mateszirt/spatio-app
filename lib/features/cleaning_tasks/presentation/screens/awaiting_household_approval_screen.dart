import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/utils/top_snack_bar.dart';

class AwaitingHouseholdApprovalScreen extends ConsumerStatefulWidget {
  const AwaitingHouseholdApprovalScreen({super.key});

  @override
  ConsumerState<AwaitingHouseholdApprovalScreen> createState() =>
      _AwaitingHouseholdApprovalScreenState();
}

class _AwaitingHouseholdApprovalScreenState
    extends ConsumerState<AwaitingHouseholdApprovalScreen> {
  Timer? _pollingTimer;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    // Auto-poll approval status every 8 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _pollStatusSilently();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollStatusSilently() async {
    if (!mounted || _isChecking) return;
    try {
      await ref.read(authProvider.notifier).checkApprovalStatus();
    } catch (_) {}
  }

  Future<void> _handleManualCheck() async {
    setState(() => _isChecking = true);
    try {
      await ref.read(authProvider.notifier).checkApprovalStatus();
      if (!mounted) return;
      final currentAuth = ref.read(authProvider);
      if (!currentAuth.isPendingApproval) {
        showTopSnackBar(context, '🎉 Jóváhagyva! Üdv a családban!');
      } else {
        showTopSnackBar(
          context,
          'A kérelem még jóváhagyásra vár az adminisztrátornál.',
        );
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, 'Hiba az ellenőrzés során: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Icon Header
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00897B).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.home_work_rounded,
                        color: Color(0xFF00897B),
                        size: 44,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    AppStrings.appName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Status Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Animated Pending Icon
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFDE68A), width: 2),
                          ),
                          child: const Icon(
                            Icons.hourglass_top_rounded,
                            color: Color(0xFFD97706),
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 18),

                        const Text(
                          'Csatlakozási kérelem elküldve!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          'A(z) "${authState.householdName ?? 'Kiválasztott'}" háztartáshoz való csatlakozásod jóváhagyásra vár.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Info Box
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.shield_outlined,
                                      size: 16, color: Color(0xFF00897B)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Biztonsági jóváhagyás',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'A nem kívánt vagy téves belépések megakadályozása érdekében a háztartás adminisztrátorának (szülő) a Household fülön el kell fogadnia a kérelmedet.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Button: Check Status
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00897B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isChecking ? null : _handleManualCheck,
                            icon: _isChecking
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 20),
                            label: Text(
                              _isChecking
                                  ? 'Ellenőrzés folyamatban...'
                                  : 'Állapot ellenőrzése',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Cancel / Sign Out Button
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => ref.read(authProvider.notifier).signOut(),
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: const Text(
                              'Kijelentkezés / Másik fiók',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
