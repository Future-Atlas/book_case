import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/supabase_service.dart';

class ProfileOnboardingGate extends StatefulWidget {
  const ProfileOnboardingGate({super.key, required this.child});

  final Widget child;

  @override
  State<ProfileOnboardingGate> createState() => _ProfileOnboardingGateState();
}

class _ProfileOnboardingGateState extends State<ProfileOnboardingGate> {
  String? _checkedUserId;
  Future<bool>? _registrationFuture;

  void _refresh(SupabaseService service) {
    setState(() {
      _registrationFuture = service.hasCompletedRegistration(
        forceRefresh: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SupabaseService>(
      builder: (context, service, _) {
        if (!service.isAuthenticated) {
          _checkedUserId = null;
          _registrationFuture = null;
          return widget.child;
        }

        final userId = service.activeProfileId;
        if (_checkedUserId != userId || _registrationFuture == null) {
          _checkedUserId = userId;
          _registrationFuture = service.hasCompletedRegistration();
        }

        return FutureBuilder<bool>(
          future: _registrationFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF06C755)),
                ),
              );
            }
            if (snapshot.data == true) return widget.child;
            return ProfileOnboardingScreen(
              onCompleted: () => _refresh(service),
            );
          },
        );
      },
    );
  }
}

class ProfileOnboardingScreen extends StatefulWidget {
  const ProfileOnboardingScreen({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  State<ProfileOnboardingScreen> createState() =>
      _ProfileOnboardingScreenState();
}

class _ProfileOnboardingScreenState extends State<ProfileOnboardingScreen> {
  final _personalFormKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _userIdController = TextEditingController();

  DateTime? _birthDate;
  int _step = 0;
  bool _isSaving = false;
  bool _didPrefill = false;
  String? _userIdError;

  static const _reservedUserIds = {
    'admin',
    'administrator',
    'support',
    'sharemarium',
    'system',
    'official',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrefill) return;
    _didPrefill = true;
    final metadata = Provider.of<SupabaseService>(
      context,
      listen: false,
    ).currentUser?.userMetadata;
    final suggestedName = metadata?['full_name'] ?? metadata?['name'];
    if (suggestedName is String) {
      _fullNameController.text = suggestedName.trim();
    }
    final suggestedUsername =
        metadata?['user_name'] ?? metadata?['preferred_username'];
    if (suggestedUsername is String) {
      _usernameController.text = suggestedUsername.trim();
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: '生年月日を選択',
    );
    if (selected != null && mounted) {
      setState(() => _birthDate = selected);
    }
  }

  void _continueToProfile() {
    if (!_personalFormKey.currentState!.validate()) return;
    if (_birthDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('生年月日を選択してください。')));
      return;
    }
    setState(() => _step = 1);
  }

  Future<void> _complete() async {
    setState(() => _userIdError = null);
    if (!_profileFormKey.currentState!.validate() || _birthDate == null) return;

    setState(() => _isSaving = true);
    final service = Provider.of<SupabaseService>(context, listen: false);
    final normalizedUserId = _userIdController.text.trim().toLowerCase();
    final available = await service.isPublicUserIdAvailable(normalizedUserId);
    if (!mounted) return;
    if (!available) {
      setState(() {
        _isSaving = false;
        _userIdError = 'このユーザーIDはすでに使用されています。';
      });
      return;
    }

    final error = await service.completeRegistration(
      fullName: _fullNameController.text,
      birthDate: _birthDate!,
      phoneNumber: _phoneController.text,
      username: _usernameController.text,
      userId: normalizedUserId,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    widget.onCompleted();
  }

  String _dateLabel(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}年$month月$day日';
  }

  String? _validatePhone(String? value) {
    final normalized = (value ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(normalized)) {
      return '有効な電話番号を入力してください。';
    }
    return null;
  }

  String? _validateUserId(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(normalized)) {
      return '半角英小文字・数字・_で3〜20文字にしてください。';
    }
    if (_reservedUserIds.contains(normalized)) {
      return 'このユーザーIDは使用できません。';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('利用登録'),
        actions: [
          TextButton(
            onPressed: _isSaving
                ? null
                : () => Provider.of<SupabaseService>(
                    context,
                    listen: false,
                  ).signOut(),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            child: const Text('ログアウト'),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _step == 0 ? 0.5 : 1,
                        minHeight: 6,
                        color: const Color(0xFFFF1F1F),
                        backgroundColor: Colors.white24,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_step + 1} / 2',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                if (_step == 0) _buildPersonalStep() else _buildProfileStep(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalStep() {
    return Form(
      key: _personalFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '基本情報を入力してください',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '氏名・生年月日・電話番号は公開されず、登録情報の管理、年齢確認、不正利用防止及びお問い合わせ対応のために使用します。',
            style: TextStyle(color: Colors.white70, height: 1.6),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _fullNameController,
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.next,
            maxLength: 100,
            decoration: _inputDecoration('氏名'),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return '氏名を入力してください。';
              if (text.length > 100) return '氏名は100文字以内で入力してください。';
              return null;
            },
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _selectBirthDate,
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: _inputDecoration('生年月日').copyWith(
                suffixIcon: const Icon(
                  Icons.calendar_month,
                  color: Colors.white70,
                ),
                errorText: null,
              ),
              child: Text(
                _birthDate == null ? '選択してください' : _dateLabel(_birthDate!),
                style: TextStyle(
                  color: _birthDate == null ? Colors.white54 : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          TextFormField(
            controller: _phoneController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            decoration: _inputDecoration('電話番号').copyWith(
              hintText: '09012345678',
              helperText: 'ハイフン付きでも入力できます。現時点ではSMS確認は行いません。',
            ),
            validator: _validatePhone,
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _continueToProfile,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF1F1F),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('次へ'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStep() {
    return Form(
      key: _profileFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '公開プロフィールを設定してください',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'ユーザーネームとユーザーIDは他の利用者に公開されます。ユーザーIDはサービス内で重複できません。',
            style: TextStyle(color: Colors.white70, height: 1.6),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _usernameController,
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.next,
            maxLength: 30,
            decoration: _inputDecoration(
              'ユーザーネーム',
            ).copyWith(helperText: 'プロフィールに表示される名前です。'),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'ユーザーネームを入力してください。';
              if (text.length > 30) return '30文字以内で入力してください。';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _userIdController,
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.done,
            maxLength: 20,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
              const _LowerCaseTextFormatter(),
            ],
            decoration: _inputDecoration('ユーザーID').copyWith(
              prefixText: '@',
              helperText: '半角英小文字・数字・_を使用できます。',
              errorText: _userIdError,
            ),
            validator: _validateUserId,
            onChanged: (_) {
              if (_userIdError != null) setState(() => _userIdError = null);
            },
            onFieldSubmitted: (_) {
              if (!_isSaving) _complete();
            },
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () => setState(() => _step = 0),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('戻る'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _isSaving ? null : _complete,
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
                      : const Text('登録を完了する'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
      helperStyle: const TextStyle(color: Colors.white54),
      counterStyle: const TextStyle(color: Colors.white54),
      prefixStyle: const TextStyle(color: Colors.white),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white38),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFFF1F1F), width: 2),
      ),
      errorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }
}

class _LowerCaseTextFormatter extends TextInputFormatter {
  const _LowerCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toLowerCase());
  }
}
