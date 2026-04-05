import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/providers.dart';
import '../../design/colors.dart';
import '../../design/theme.dart';
import '../../design/widgets/jetlag_button.dart';
import '../../design/widgets/jetlag_card.dart';
import '../../design/widgets/jetlag_input.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final displayName = ref.read(displayNameProvider);
    if (displayName != null) {
      _displayNameController.text = displayName;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final displayName = ref.watch(displayNameProvider);

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        foregroundColor: context.textPrimary,
        title: Text(
          'Account',
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textPrimary),
          onPressed: () => context.pop(),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: user != null
            ? _buildLoggedInView(user, displayName)
            : _buildAuthForm(),
      ),
    );
  }

  Widget _buildLoggedInView(user, String? displayName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JetlagCard(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: context.accent.withValues(alpha: 0.15),
                child: Icon(Icons.person, size: 40, color: context.accent),
              ),
              const SizedBox(height: 16),
              Text(
                displayName ?? 'Player',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              if (user.email != null)
                Text(
                  user.email!,
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildDisplayNameField(),
        const SizedBox(height: 24),
        JetlagButton(
          label: 'Sign Out',
          variant: JetlagButtonVariant.secondary,
          onPressed: _signOut,
        ),
      ],
    );
  }

  Widget _buildDisplayNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DISPLAY NAME',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: context.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _displayNameController,
          style: TextStyle(color: context.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter your display name',
            hintStyle: TextStyle(color: context.textTertiary),
            suffixIcon: IconButton(
              icon: Icon(Icons.check, color: context.accent),
              onPressed: _saveDisplayName,
            ),
          ),
          onFieldSubmitted: (_) => _saveDisplayName(),
        ),
      ],
    );
  }

  Widget _buildAuthForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toggle Sign In / Sign Up - pill selector style
          Container(
            decoration: BoxDecoration(
              color: context.surface2,
              borderRadius: BorderRadius.circular(JetlagRadii.sm),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                _AuthPill(
                  label: 'Sign In',
                  isActive: !_isSignUp,
                  onTap: () => setState(() { _isSignUp = false; _errorMessage = null; }),
                ),
                _AuthPill(
                  label: 'Sign Up',
                  isActive: _isSignUp,
                  onTap: () => setState(() { _isSignUp = true; _errorMessage = null; }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Display Name (Sign Up only)
          if (_isSignUp) ...[
            TextFormField(
              controller: _displayNameController,
              style: TextStyle(color: context.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Display Name',
                labelStyle: TextStyle(color: context.textSecondary, fontSize: 12),
                prefixIcon: Icon(Icons.person_outline, color: context.textTertiary),
              ),
              validator: (value) {
                if (_isSignUp && (value == null || value.isEmpty)) {
                  return 'Please enter a display name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],

          // Email
          TextFormField(
            controller: _emailController,
            style: TextStyle(color: context.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: TextStyle(color: context.textSecondary, fontSize: 12),
              prefixIcon: Icon(Icons.email_outlined, color: context.textTertiary),
            ),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password
          TextFormField(
            controller: _passwordController,
            style: TextStyle(color: context.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: TextStyle(color: context.textSecondary, fontSize: 12),
              prefixIcon: Icon(Icons.lock_outline, color: context.textTertiary),
            ),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (_isSignUp && value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Error Message
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: context.red, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),

          // Submit Button
          JetlagButton(
            label: _isSignUp ? 'Create Account' : 'Sign In',
            variant: JetlagButtonVariant.primary,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _submit,
          ),
          const SizedBox(height: 16),

          // Play Anonymously
          JetlagButton(
            label: 'Play without account',
            variant: JetlagButtonVariant.secondary,
            onPressed: _playAnonymously,
          ),
          const SizedBox(height: 24),

          // Forgot Password
          if (!_isSignUp)
            Center(
              child: GestureDetector(
                onTap: _forgotPassword,
                child: Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: context.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authActions = ref.read(authActionsProvider);

      if (_isSignUp) {
        await authActions.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
        await _saveDisplayName();
      } else {
        await authActions.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _playAnonymously() async {
    if (_displayNameController.text.isNotEmpty) {
      await _saveDisplayName();
    }
    if (mounted) {
      context.pop();
    }
  }

  Future<void> _saveDisplayName() async {
    final name = _displayNameController.text.trim();
    if (name.isNotEmpty) {
      await ref.read(displayNameProvider.notifier).setDisplayName(name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Display name saved')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authActionsProvider).signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email first')),
      );
      return;
    }

    try {
      await ref.read(authActionsProvider).resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _AuthPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _AuthPill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? context.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(JetlagRadii.sm - 2),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
