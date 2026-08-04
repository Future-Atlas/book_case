import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/legal_document_versions.dart';
import '../services/supabase_service.dart';
import 'community_guidelines_screen.dart';
import 'external_transmission_screen.dart';
import 'infringement_policy_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';

class LegalConsentGate extends StatefulWidget {
  const LegalConsentGate({super.key, required this.child});

  final Widget child;

  @override
  State<LegalConsentGate> createState() => _LegalConsentGateState();
}

class _LegalConsentGateState extends State<LegalConsentGate> {
  String? _checkedUserId;
  Future<bool>? _consentFuture;

  void _refreshConsent(SupabaseService service) {
    setState(() {
      _consentFuture = service.hasCurrentLegalConsent(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SupabaseService>(
      builder: (context, service, _) {
        if (!service.isAuthenticated) {
          _checkedUserId = null;
          _consentFuture = null;
          return widget.child;
        }

        final userId = service.activeProfileId;
        if (_checkedUserId != userId || _consentFuture == null) {
          _checkedUserId = userId;
          _consentFuture = service.hasCurrentLegalConsent();
        }

        return FutureBuilder<bool>(
          future: _consentFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _LegalLoadingScreen();
            }
            if (snapshot.data == true) return widget.child;
            return LegalConsentScreen(
              onAccepted: () => _refreshConsent(service),
            );
          },
        );
      },
    );
  }
}

class LegalConsentScreen extends StatefulWidget {
  const LegalConsentScreen({super.key, required this.onAccepted});

  final VoidCallback onAccepted;

  @override
  State<LegalConsentScreen> createState() => _LegalConsentScreenState();
}

class _LegalConsentScreenState extends State<LegalConsentScreen> {
  final List<bool> _checked = List<bool>.filled(5, false);
  bool _isSaving = false;

  bool get _canAccept => _checked.every((value) => value) && !_isSaving;

  Future<void> _accept() async {
    if (!_canAccept) return;
    setState(() => _isSaving = true);
    final service = Provider.of<SupabaseService>(context, listen: false);
    final error = await service.acceptCurrentLegalDocuments();
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error == null) {
      widget.onAccepted();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final documents = <_LegalDocument>[
      _LegalDocument(
        title: '利用規約',
        version: LegalDocumentVersions.terms,
        screenBuilder: (_) => const TermsScreen(),
      ),
      _LegalDocument(
        title: 'プライバシーポリシー',
        version: LegalDocumentVersions.privacy,
        screenBuilder: (_) => const PrivacyPolicyScreen(),
      ),
      _LegalDocument(
        title: 'コミュニティガイドライン',
        version: LegalDocumentVersions.communityGuidelines,
        screenBuilder: (_) => const CommunityGuidelinesScreen(),
      ),
      _LegalDocument(
        title: '権利侵害・通報ポリシー',
        version: LegalDocumentVersions.infringementPolicy,
        screenBuilder: (_) => const InfringementPolicyScreen(),
      ),
      _LegalDocument(
        title: '外部送信に関する公表事項',
        version: LegalDocumentVersions.externalTransmission,
        screenBuilder: (_) => const ExternalTransmissionScreen(),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  '規約・ポリシーの確認',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sharemariumを利用する前に、以下の最新版を確認してください。確認結果は、UID、認証provider、各文書のバージョン及び同意日時とともに保存されます。',
                  style: TextStyle(color: Colors.white70, height: 1.6),
                ),
                const SizedBox(height: 20),
                for (var index = 0; index < documents.length; index++)
                  Card(
                    color: const Color(0xFF171717),
                    child: CheckboxListTile(
                      value: _checked[index],
                      activeColor: const Color(0xFFFF1F1F),
                      checkColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() => _checked[index] = value ?? false);
                            },
                      title: TextButton(
                        style: TextButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          foregroundColor: const Color(0xFFFF3B30),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: documents[index].screenBuilder,
                            ),
                          );
                        },
                        child: Text(
                          documents[index].title,
                          style: const TextStyle(
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFFFF3B30),
                          ),
                        ),
                      ),
                      subtitle: Text(
                        'バージョン ${documents[index].version} を確認しました',
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _canAccept ? _accept : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF1F1F),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('すべて確認して同意する'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () => Provider.of<SupabaseService>(
                          context,
                          listen: false,
                        ).signOut(),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  child: const Text('同意せずログアウトする'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalLoadingScreen extends StatelessWidget {
  const _LegalLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator(color: Color(0xFFFF1F1F))),
    );
  }
}

class _LegalDocument {
  const _LegalDocument({
    required this.title,
    required this.version,
    required this.screenBuilder,
  });

  final String title;
  final String version;
  final WidgetBuilder screenBuilder;
}
