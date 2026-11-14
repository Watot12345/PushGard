import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/pushgard_api_client.dart';
import '../../../core/state/player_session_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pushgard_button.dart';

class AuthScreen extends StatefulWidget {
  final PushgardApiClient? apiClient;

  const AuthScreen({super.key, this.apiClient});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isRegister = true;
  bool _submitting = false;
  String? _errorText;

  final _handleController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  PushgardApiClient get _client => widget.apiClient ?? PushgardApiClient.instance;

  @override
  void dispose() {
    _handleController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitManual() async {
    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final Map<String, dynamic> res;

      if (_isRegister) {
        res = await _client.register(
          handle: _handleController.text.trim(),
          email: email,
          password: password,
        );
      } else {
        res = await _client.login(email: email, password: password);
      }

      final player = res['player'] as Map<String, dynamic>?;
      if (player != null) {
        PlayerSessionStore.instance.applyAuthenticatedPlayer(player);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = e.toString().replaceFirst('Exception: ', '');
          _submitting = false;
        });
      }
    }
  }

  Future<void> _confirmGuestMode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'GUEST MODE WARNING',
          style: AppTypography.cardHeadline(color: AppColors.volt),
        ),
        content: Text(
          'Guest Mode creates a real unique player handle in the PushGard database so your EGO Rating and battles are recorded.\n\nHowever, there is NO email or social backup recovery. Clearing app data or switching devices permanently forfeits access to this guest account.',
          style: AppTypography.body(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.volt,
              foregroundColor: AppColors.background,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('CREATE GUEST'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      final customHandle = _handleController.text.trim();
      final res = await _client.continueAsGuest(
        handle: customHandle.isNotEmpty ? customHandle : null,
      );
      final player = res['player'] as Map<String, dynamic>?;
      if (player != null) {
        PlayerSessionStore.instance.applyAuthenticatedPlayer(player);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = e.toString().replaceFirst('Exception: ', '');
          _submitting = false;
        });
      }
    }
  }

  Future<void> _submitSocial(String provider) async {
    final emailCtrl = TextEditingController();
    final handleCtrl = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          provider == 'google' ? 'CONTINUE WITH GMAIL' : 'CONTINUE WITH FACEBOOK',
          style: AppTypography.cardHeadline(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Link your ${provider == 'google' ? 'Google / Gmail' : 'Facebook'} identity to keep a recoverable EGO profile.',
              style: AppTypography.body(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: provider == 'google' ? 'Gmail address' : 'Account email',
                labelStyle: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: handleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Arena Handle (optional)',
                labelStyle: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.volt,
              foregroundColor: AppColors.background,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('CONTINUE'),
          ),
        ],
      ),
    );

    if (submitted != true) return;
    final email = emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _errorText = 'Please enter your email to continue.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      final res = await _client.oauthSignIn(
        provider: provider,
        providerId: '${provider}_${email.toLowerCase()}',
        email: email,
        handle: handleCtrl.text.trim().isNotEmpty ? handleCtrl.text.trim() : null,
      );
      final player = res['player'] as Map<String, dynamic>?;
      if (player != null) {
        PlayerSessionStore.instance.applyAuthenticatedPlayer(player);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = e.toString().replaceFirst('Exception: ', '');
          _submitting = false;
        });
      }
    }
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.volt, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        title: Text(
          'ARENA ACCOUNT',
          style: AppTypography.trackedLabel(color: AppColors.volt, fontSize: 13),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mode Toggle: Register vs Sign In
              Row(
                children: [
                  Expanded(
                    child: _modeChip('REGISTER', _isRegister, () {
                      setState(() => _isRegister = true);
                    }),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _modeChip('SIGN IN', !_isRegister, () {
                      setState(() => _isRegister = false);
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (_errorText != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.crimson.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.crimson),
                  ),
                  child: Text(
                    _errorText!,
                    style: AppTypography.body(color: Colors.white, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (_isRegister) ...[
                TextField(
                  controller: _handleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _fieldDecoration('Arena Handle (e.g. SPARTAN_99)'),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDecoration('Email Address'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDecoration('Password (min 8 chars)'),
              ),
              const SizedBox(height: 18),

              PushGardButton(
                text: _submitting
                    ? 'CONNECTING...'
                    : (_isRegister ? 'CREATE ACCOUNT' : 'SIGN IN'),
                icon: Icons.login_rounded,
                variant: ButtonVariant.primary,
                onPressed: _submitting ? null : _submitManual,
              ),

              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(child: Divider(color: Colors.white12)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OR CONTINUE WITH',
                      style: AppTypography.telemetryCode(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: Colors.white12)),
                ],
              ),
              const SizedBox(height: 16),

              PushGardButton(
                text: 'CONTINUE WITH GMAIL / GOOGLE',
                icon: Icons.mail_outline_rounded,
                variant: ButtonVariant.secondary,
                height: 52,
                onPressed: _submitting ? null : () => _submitSocial('google'),
              ),
              const SizedBox(height: 10),
              PushGardButton(
                text: 'CONTINUE WITH FACEBOOK',
                icon: Icons.public_rounded,
                variant: ButtonVariant.secondary,
                height: 52,
                onPressed: _submitting ? null : () => _submitSocial('facebook'),
              ),
              const SizedBox(height: 18),

              // Guest Mode with explicit no-backup warning
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.volt,
                  side: BorderSide(color: AppColors.volt.withValues(alpha: 0.45)),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _submitting
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        _confirmGuestMode();
                      },
                icon: const Icon(Icons.person_outline_rounded),
                label: Text(
                  'PLAY AS GUEST (NO BACKUP RECOVERY)',
                  style: AppTypography.telemetryCode(
                    color: AppColors.volt,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.volt : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.cardHeadline(
            color: active ? AppColors.background : AppColors.textSecondary,
          ).copyWith(fontSize: 13),
        ),
      ),
    );
  }
}
