import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/utils/top_snack_bar.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isSignUp = false;
  bool _obscurePassword = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _householdNameController = TextEditingController(text: 'Family Home');
  final _inviteCodeController = TextEditingController();

  String _selectedRole = 'parent'; // 'parent' or 'child'
  bool _createNewHousehold = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _emailController.removeListener(_onFieldChanged);
    _passwordController.removeListener(_onFieldChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _householdNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  // --- Live Validation Helpers ---
  bool get _isEmailValid {
    final email = _emailController.text.trim();
    if (email.isEmpty) return false;
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasUppercase => _passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasNumber => _passwordController.text.contains(RegExp(r'[0-9]'));
  bool get _isPasswordValid => _hasMinLength && _hasUppercase && _hasNumber;

  bool get _isFormValid {
    if (_isSignUp) {
      final nameOk = _nameController.text.trim().isNotEmpty;
      return _isEmailValid && _isPasswordValid && nameOk;
    } else {
      return _emailController.text.trim().isNotEmpty && _passwordController.text.isNotEmpty;
    }
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showTopSnackBar(context, 'Please enter email and password', isError: true);
      return;
    }

    if (_isSignUp && !_isEmailValid) {
      showTopSnackBar(context, 'Please enter a valid email address', isError: true);
      return;
    }

    if (_isSignUp && !_isPasswordValid) {
      showTopSnackBar(context, 'Please ensure password meets all security criteria', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        final name = _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : email.split('@').first;

        await ref.read(authProvider.notifier).signUp(
              email: email,
              password: password,
              name: name,
              role: _selectedRole,
              createNewHousehold: _selectedRole == 'parent' && _createNewHousehold,
              householdName: _householdNameController.text.trim(),
              inviteCode: _inviteCodeController.text.trim(),
            );

        final authState = ref.read(authProvider);
        if (mounted) {
          if (authState.isAwaitingEmailConfirmation) {
            showTopSnackBar(
              context,
              'Verification email sent to $email. Please confirm your account!',
            );
          } else {
            showTopSnackBar(context, 'Welcome to Spatio, $name!');
            widget.onLoginSuccess?.call();
          }
        }
      } else {
        await ref.read(authProvider.notifier).signIn(
              email: email,
              password: password,
            );
        final authState = ref.read(authProvider);
        if (mounted) {
          if (authState.isAwaitingEmailConfirmation) {
            showTopSnackBar(
              context,
              'Please confirm your email address before logging in.',
              isError: true,
            );
          } else {
            showTopSnackBar(context, 'Signed in successfully!');
            widget.onLoginSuccess?.call();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        showTopSnackBar(context, errorMsg, isError: true);

        // If duplicate email, switch to Sign In automatically
        if (errorMsg.toLowerCase().contains('already registered') ||
            errorMsg.toLowerCase().contains('already exists')) {
          setState(() {
            _isSignUp = false;
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkEmailConfirmationAgain() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      showTopSnackBar(context, 'Please enter your password to verify', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).signIn(email: email, password: password);
      final authState = ref.read(authProvider);
      if (mounted) {
        if (authState.isAuthenticated) {
          showTopSnackBar(context, 'Email verified! Welcome to Spatio.');
          widget.onLoginSuccess?.call();
        } else {
          showTopSnackBar(
            context,
            'Email not confirmed yet. Please click the link in your email inbox.',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          context,
          'Email not confirmed yet. Please click the link in your email.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendVerification() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    try {
      await ref.read(authProvider.notifier).resendConfirmationEmail(email);
      if (mounted) {
        showTopSnackBar(context, 'New confirmation email sent to $email');
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, 'Could not resend email: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: authState.isAwaitingEmailConfirmation
                    ? _buildAwaitingEmailConfirmationView(authState.email ?? _emailController.text.trim())
                    : _buildAuthForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAwaitingEmailConfirmationView(String email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF00897B).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              color: Color(0xFF00897B),
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Verify Your Email',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We have sent a verification link to:\n$email',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.4),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: Color(0xFF00897B)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Please open your email client, click the confirmation link, then return here.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00897B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isLoading ? null : _checkEmailConfirmationAgain,
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_circle_outline, size: 20),
          label: const Text(
            'I\'ve Confirmed My Email',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF00897B),
            side: const BorderSide(color: Color(0xFF80CBC4)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _resendVerification,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Resend Verification Email'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            ref.read(authProvider.notifier).cancelAwaitingEmailConfirmation();
            setState(() => _isSignUp = false);
          },
          child: const Text('Back to Sign In'),
        ),
      ],
    );
  }

  Widget _buildAuthForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Brand Header
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00897B).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.home_work_rounded,
              color: Color(0xFF00897B),
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: 14),
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
        const SizedBox(height: 4),
        Text(
          _isSignUp ? AppStrings.signUp : AppStrings.loginSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),

        // Toggle Tabs: Sign In / Create Account
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _isSignUp = false),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: !_isSignUp ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: !_isSignUp
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                              )
                            ]
                          : null,
                    ),
                    child: Text(
                      AppStrings.signIn,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: !_isSignUp ? FontWeight.bold : FontWeight.normal,
                        color: !_isSignUp ? const Color(0xFF00897B) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _isSignUp = true),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _isSignUp ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _isSignUp
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                              )
                            ]
                          : null,
                    ),
                    child: Text(
                      AppStrings.signUp,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _isSignUp ? FontWeight.bold : FontWeight.normal,
                        color: _isSignUp ? const Color(0xFF00897B) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Sign Up Extra Fields
        if (_isSignUp) ...[
          // Name Field
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: AppStrings.name,
              hintText: 'e.g. Sarah Smith',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          // Role Selector (Parent / Child)
          const Text(
            AppStrings.selectRole,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedRole = 'parent'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: _selectedRole == 'parent'
                          ? const Color(0xFF00897B).withValues(alpha: 0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedRole == 'parent'
                            ? const Color(0xFF00897B)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('👩‍💼'),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            AppStrings.roleParent,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _selectedRole == 'parent' ? FontWeight.bold : FontWeight.normal,
                              color: _selectedRole == 'parent' ? const Color(0xFF004D40) : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() {
                    _selectedRole = 'child';
                    _createNewHousehold = false; // Children always join existing
                  }),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: _selectedRole == 'child'
                          ? const Color(0xFF00897B).withValues(alpha: 0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedRole == 'child'
                            ? const Color(0xFF00897B)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('👦'),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            AppStrings.roleChild,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _selectedRole == 'child' ? FontWeight.bold : FontWeight.normal,
                              color: _selectedRole == 'child' ? const Color(0xFF004D40) : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // If Parent: choice to create new household or join existing
          if (_selectedRole == 'parent') ...[
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _createNewHousehold = true),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _createNewHousehold ? const Color(0xFFE0F2F1) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _createNewHousehold ? const Color(0xFF00897B) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 16,
                            color: _createNewHousehold ? const Color(0xFF00897B) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'New Household',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _createNewHousehold ? FontWeight.bold : FontWeight.w500,
                                color: _createNewHousehold ? const Color(0xFF00897B) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _createNewHousehold = false),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_createNewHousehold ? const Color(0xFFE0F2F1) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: !_createNewHousehold ? const Color(0xFF00897B) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.vpn_key_outlined,
                            size: 16,
                            color: !_createNewHousehold ? const Color(0xFF00897B) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Join with Code',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: !_createNewHousehold ? FontWeight.bold : FontWeight.w500,
                                color: !_createNewHousehold ? const Color(0xFF00897B) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_createNewHousehold)
              TextField(
                controller: _householdNameController,
                decoration: InputDecoration(
                  labelText: AppStrings.householdName,
                  hintText: AppStrings.householdNameHint,
                  prefixIcon: const Icon(Icons.home_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              )
            else
              TextField(
                controller: _inviteCodeController,
                decoration: InputDecoration(
                  labelText: '8-Digit Invite Code (e.g. SPATIO-1)',
                  hintText: 'SPATIO-1',
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
          ] else ...[
            // Child must join existing household
            TextField(
              controller: _inviteCodeController,
              decoration: InputDecoration(
                labelText: 'Enter Parent\'s Invite Code (e.g. SPATIO-1)',
                hintText: 'SPATIO-1',
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
          const SizedBox(height: 14),
        ],

        // Email Field with Live Validation Indicator
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: AppStrings.email,
            prefixIcon: const Icon(Icons.email_outlined),
            suffixIcon: _emailController.text.trim().isEmpty
                ? null
                : Icon(
                    _isEmailValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: _isEmailValid ? const Color(0xFF00897B) : Colors.red.shade400,
                    size: 20,
                  ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        if (_emailController.text.isNotEmpty && !_isEmailValid) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.info_outline, size: 13, color: Colors.red.shade400),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Please enter a valid email address (e.g. name@domain.com)',
                  style: TextStyle(fontSize: 11, color: Colors.red.shade600),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),

        // Password Field with Visibility Toggle and Live Validation
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: AppStrings.password,
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: Colors.grey.shade600,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),

        // Live Password Requirements (shown during sign up)
        if (_isSignUp) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Password requirements:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                _buildValidationRuleRow('At least 8 characters', _hasMinLength),
                const SizedBox(height: 4),
                _buildValidationRuleRow('At least one uppercase letter (A-Z)', _hasUppercase),
                const SizedBox(height: 4),
                _buildValidationRuleRow('At least one number (0-9)', _hasNumber),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),

        // Submit Button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00897B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: (_isLoading || (_isSignUp && !_isFormValid)) ? null : _handleSubmit,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  _isSignUp ? AppStrings.signUp : AppStrings.signIn,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildValidationRuleRow(String text, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 14,
          color: isMet ? const Color(0xFF00897B) : Colors.grey.shade400,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: isMet ? const Color(0xFF00695C) : Colors.grey.shade600,
              fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
