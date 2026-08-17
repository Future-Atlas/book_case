import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/supabase_service.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';
import 'external_transmission_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSubmitting = false;

  // Providers can be enabled here after their Supabase OAuth setup is ready.
  final Set<String> _enabledLoginProviders = {'x'};

  Future<bool> _showTermsDialog() async {
    var agreedTerms = false;
    var agreedPrivacy = false;
    var confirmedExternalTransmission = false;
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.black,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            '利用規約・プライバシーポリシー',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '続けるには利用規約とプライバシーポリシーへの同意、外部送信内容の確認が必要です。',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              _AgreementRow(
                value: agreedTerms,
                label: '利用規約',
                onChanged: (value) => setDialogState(() => agreedTerms = value),
                onOpen: () => Navigator.of(
                  dialogContext,
                ).push(MaterialPageRoute(builder: (_) => const TermsScreen())),
              ),
              _AgreementRow(
                value: confirmedExternalTransmission,
                label: '外部送信に関する公表事項',
                actionText: 'を確認した',
                onChanged: (value) =>
                    setDialogState(() => confirmedExternalTransmission = value),
                onOpen: () => Navigator.of(dialogContext).push(
                  MaterialPageRoute(
                    builder: (_) => const ExternalTransmissionScreen(),
                  ),
                ),
              ),
              _AgreementRow(
                value: agreedPrivacy,
                label: 'プライバシーポリシー',
                onChanged: (value) =>
                    setDialogState(() => agreedPrivacy = value),
                onOpen: () => Navigator.of(dialogContext).push(
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed:
                  agreedTerms && agreedPrivacy && confirmedExternalTransmission
                  ? () => Navigator.of(dialogContext).pop(true)
                  : null,
              child: const Text('同意して続ける'),
            ),
          ],
        ),
      ),
    );
    return agreed == true;
  }

  Future<void> _signIn(
    Future<String?> Function(SupabaseService service) action,
  ) async {
    if (!await _showTermsDialog() || !mounted) return;
    setState(() => _isSubmitting = true);
    final error = await action(
      Provider.of<SupabaseService>(context, listen: false),
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Widget _loginButton({
    required String label,
    required Color background,
    required Future<String?> Function(SupabaseService service) action,
    Color foreground = Colors.white,
  }) {
    return SizedBox(
      width: 220,
      height: 42,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : () => _signIn(action),
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          shape: const RoundedRectangleBorder(),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        child: Text('$labelでログイン'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SupabaseService>(
      builder: (context, service, _) {
        if (service.isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop(true);
            }
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFFEAEAEA),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                        ),
                        children: [
                          TextSpan(
                            text: 'Share',
                            style: TextStyle(color: Color(0xFFFF1F1F)),
                          ),
                          TextSpan(
                            text: 'marium',
                            style: TextStyle(color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_enabledLoginProviders.contains('google')) ...[
                      _loginButton(
                        label: 'Google',
                        background: Colors.yellow,
                        foreground: Colors.black,
                        action: (service) => service.signInWithGoogle(),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _loginButton(
                      label: 'X',
                      background: Colors.black,
                      action: (service) => service.signInWithX(),
                    ),
                    if (_enabledLoginProviders.contains('facebook')) ...[
                      const SizedBox(height: 10),
                      _loginButton(
                        label: 'Facebook',
                        background: const Color(0xFF1877F2),
                        action: (service) => service.signInWithFacebook(),
                      ),
                    ],
                    if (_enabledLoginProviders.contains('apple')) ...[
                      const SizedBox(height: 10),
                      _loginButton(
                        label: 'Apple',
                        background: const Color(0xFFB71C1C),
                        action: (service) => service.signInWithApple(),
                      ),
                    ],
                    if (_enabledLoginProviders.contains('discord')) ...[
                      const SizedBox(height: 10),
                      _loginButton(
                        label: 'Discord',
                        background: const Color(0xFF4A148C),
                        action: (service) => service.signInWithDiscord(),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const SizedBox(
                      width: 280,
                      child: Text(
                        '現在利用できるログイン方法はXです。Googleログインは近日追加予定です。',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      child: const Text('戻る'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AgreementRow extends StatelessWidget {
  const _AgreementRow({
    required this.value,
    required this.label,
    required this.onChanged,
    required this.onOpen,
    this.actionText = 'に同意する',
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpen;
  final String actionText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: value,
          activeColor: const Color(0xFFFF1F1F),
          checkColor: Colors.white,
          side: const BorderSide(color: Colors.white70),
          onChanged: (value) => onChanged(value ?? false),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white),
              children: [
                TextSpan(
                  text: label,
                  style: const TextStyle(
                    color: Color(0xFFFF1F1F),
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = onOpen,
                ),
                TextSpan(text: ' $actionText'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
