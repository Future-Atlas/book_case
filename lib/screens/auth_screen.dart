import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/supabase_service.dart';
import 'terms_screen.dart';
import 'privacy_policy_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSubmitting = false;

  Future<void> _sendMagicLink(String email, String providerLabel) async {
    setState(() => _isSubmitting = true);
    final service = Provider.of<SupabaseService>(context, listen: false);
    final error = await service.sendMagicLink(email: email);

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$providerLabel 経由としてマジックリンクを送信しました。メールを確認してください。'),
      ),
    );

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  /// 利用規約・プライバシーポリシーへの同意ダイアログを表示する。
  /// 両方にチェックして「同意して続ける」を押した場合のみ true を返す。
  Future<bool> _showTermsDialog() async {
    bool agreedTerms = false;
    bool agreedPrivacy = false;

    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.black,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.white24),
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text(
                '利用規約・プライバシーポリシー',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '続けるには以下の両方に同意してください。',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  // 利用規約
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: agreedTerms,
                        activeColor: const Color(0xFFFF1F1F),
                        checkColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        onChanged: (v) =>
                            setDialogState(() => agreedTerms = v ?? false),
                      ),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                            ),
                            children: [
                              TextSpan(
                                text: '利用規約',
                                style: const TextStyle(
                                  color: Color(0xFFFF1F1F),
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.of(dialogContext).push(
                                      MaterialPageRoute(
                                        builder: (_) => const TermsScreen(),
                                      ),
                                    );
                                  },
                              ),
                              const TextSpan(text: ' に同意する'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // プライバシーポリシー
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: agreedPrivacy,
                        activeColor: const Color(0xFFFF1F1F),
                        checkColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        onChanged: (v) =>
                            setDialogState(() => agreedPrivacy = v ?? false),
                      ),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                            ),
                            children: [
                              TextSpan(
                                text: 'プライバシーポリシー',
                                style: const TextStyle(
                                  color: Color(0xFFFF1F1F),
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.of(dialogContext).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const PrivacyPolicyScreen(),
                                      ),
                                    );
                                  },
                              ),
                              const TextSpan(text: ' に同意する'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: (agreedTerms && agreedPrivacy)
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF1F1F),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[800],
                    disabledForegroundColor: Colors.white54,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text('同意して続ける'),
                ),
              ],
            );
          },
        );
      },
    );

    return agreed == true;
  }

  Future<void> _showEmailPrompt(String providerLabel) async {
    // まず利用規約・プライバシーポリシーへの同意を確認する
    final agreed = await _showTermsDialog();
    if (!agreed) return;
    if (!mounted) return;

    final emailController = TextEditingController();

    final email = await showDialog<String>(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: Text('$providerLabel でログイン'),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'メールアドレス',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = emailController.text.trim();
                Navigator.of(context).pop(value);
              },
              child: const Text('送信'),
            ),
          ],
        );
      },
    );

    final normalized = (email ?? '').trim();
    if (normalized.isEmpty) return;
    if (!normalized.contains('@')) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('メールアドレス形式が不正です。')));
      return;
    }

    await _sendMagicLink(normalized, providerLabel);
  }

  Future<void> _signInWithGoogle() async {
    final agreed = await _showTermsDialog();
    if (!agreed || !mounted) return;

    setState(() => _isSubmitting = true);
    final service = Provider.of<SupabaseService>(context, listen: false);
    final error = await service.signInWithGoogle();

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Widget _buildLoginButton({
    required String label,
    required Color background,
    Color foreground = Colors.white,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 200,
      height: 36,
      child: ElevatedButton(
        onPressed: _isSubmitting
            ? null
            : onPressed ?? () => _showEmailPrompt(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 28 / 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text('$labelでログイン'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SupabaseService>(
      builder: (context, service, _) {
        if (service.isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(true);
            }
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFFEAEAEA),
          body: Center(
            child: Container(
              width: 360,
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 56,
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
                  const SizedBox(height: 22),
                  _buildLoginButton(
                    label: 'Google',
                    background: const Color(0xFFF5CF00),
                    foreground: Colors.black,
                    onPressed: _signInWithGoogle,
                  ),
                  const SizedBox(height: 10),
                  _buildLoginButton(label: 'X', background: Colors.black),
                  const SizedBox(height: 10),
                  _buildLoginButton(
                    label: 'Instagram',
                    background: const Color(0xFFC80E5A),
                  ),
                  const SizedBox(height: 10),
                  _buildLoginButton(
                    label: 'LINE',
                    background: const Color(0xFF10C93A),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'GoogleはOAuth認証を使用します。\nその他のボタンは現在メールリンク認証です。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            Navigator.of(context).maybePop();
                          },
                    child: const Text('戻る'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
