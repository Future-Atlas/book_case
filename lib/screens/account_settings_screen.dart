import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/supabase_service.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key, required this.onAccountDeleted});

  final VoidCallback onAccountDeleted;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _isDeleting = false;
  bool _isLoadingPrivacy = true;
  bool _isSavingPrivacy = false;
  bool _isPrivate = false;
  bool _privacyLoadStarted = false;
  Future<Map<String, dynamic>?>? _accountDetailsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _accountDetailsFuture ??= Provider.of<SupabaseService>(
      context,
      listen: false,
    ).fetchCurrentAccountDetails();
    if (!_privacyLoadStarted) {
      _privacyLoadStarted = true;
      _loadPrivacySetting();
    }
  }

  Future<void> _loadPrivacySetting() async {
    final service = Provider.of<SupabaseService>(context, listen: false);
    final value = await service.fetchCurrentProfilePrivacy();
    if (!mounted) return;
    setState(() {
      _isPrivate = value ?? false;
      _isLoadingPrivacy = false;
    });
  }

  Future<void> _updatePrivacySetting(bool value) async {
    final previousValue = _isPrivate;
    setState(() {
      _isPrivate = value;
      _isSavingPrivacy = true;
    });

    final service = Provider.of<SupabaseService>(context, listen: false);
    final error = await service.updateCurrentProfilePrivacy(isPrivate: value);
    if (!mounted) return;

    setState(() {
      _isSavingPrivacy = false;
      if (error != null) _isPrivate = previousValue;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? (value ? '鍵アカウントに設定しました。' : 'アカウントを公開しました。')),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('本当に退会しますか？'),
        content: const Text(
          'アカウント、プロフィール、投稿、本棚、お気に入り及び同意履歴が削除されます。この操作は取り消せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('退会して削除する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    final service = Provider.of<SupabaseService>(context, listen: false);
    final error = await service.deleteCurrentAccount();
    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    widget.onAccountDeleted();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('退会処理が完了しました。')));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SupabaseService>(
      builder: (context, service, _) {
        if (!service.isAuthenticated) {
          return const Center(child: Text('アカウント設定を利用するにはログインしてください。'));
        }

        final user = service.currentUser;
        final provider = user?.appMetadata['provider']?.toString() ?? '不明';
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'アカウント設定',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('メールアドレス'),
                        subtitle: Text(user?.email ?? '未登録'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('認証provider'),
                        subtitle: Text(provider),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('UID'),
                        subtitle: Text(user?.id ?? ''),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: SwitchListTile(
                    secondary: Icon(
                      _isPrivate ? Icons.lock_outline : Icons.public,
                    ),
                    title: const Text('鍵アカウント'),
                    subtitle: Text(
                      _isPrivate
                          ? '投稿・本棚・お気に入りは、本人以外には表示されません。'
                          : '投稿・本棚・お気に入りは公開されます。',
                    ),
                    value: _isPrivate,
                    onChanged: _isLoadingPrivacy || _isSavingPrivacy
                        ? null
                        : _updatePrivacySetting,
                  ),
                ),
                if (_isLoadingPrivacy || _isSavingPrivacy) ...[
                  const SizedBox(height: 6),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                const SizedBox(height: 16),
                FutureBuilder<Map<String, dynamic>?>(
                  future: _accountDetailsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      );
                    }
                    final details = snapshot.data;
                    final phone = details?['phone_number']?.toString();
                    final verified = details?['phone_verified_at'] != null;
                    return Card(
                      child: Column(
                        children: [
                          ListTile(
                            title: const Text('氏名（非公開）'),
                            subtitle: Text(
                              details?['full_name']?.toString() ?? '未登録',
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            title: const Text('生年月日（非公開）'),
                            subtitle: Text(
                              details?['birth_date']?.toString() ?? '未登録',
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            title: const Text('電話番号（非公開）'),
                            subtitle: Text(
                              phone == null
                                  ? '未登録'
                                  : verified
                                  ? '$phone（確認済み）'
                                  : '$phone（未確認）',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                const Text(
                  '退会',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '退会するとアカウントに紐づくデータが削除され、元に戻すことはできません。',
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _isDeleting ? null : _deleteAccount,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_forever_outlined),
                  label: const Text('退会してアカウントを削除'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
