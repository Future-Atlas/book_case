import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/profile_onboarding_screen.dart';

void main() {
  group('個人情報変更用パスワード', () {
    test('大文字・小文字・数字を含む8〜20文字を受け付ける', () {
      expect(validatePrivacyPassword('Share123'), isNull);
      expect(validatePrivacyPassword('Abcdefg1Abcdefg1'), isNull);
    });

    test('条件を満たさないパスワードを拒否する', () {
      expect(validatePrivacyPassword('Short1'), isNotNull);
      expect(validatePrivacyPassword('lowercase1'), isNotNull);
      expect(validatePrivacyPassword('UPPERCASE1'), isNotNull);
      expect(validatePrivacyPassword('NoNumbers'), isNotNull);
      expect(validatePrivacyPassword('Abcdefghij12345678901'), isNotNull);
    });
  });
}
