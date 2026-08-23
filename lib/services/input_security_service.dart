class InputSecurityService {
  static final RegExp _scriptPattern = RegExp(
    r'(<\s*/?\s*script\b|javascript:|on[a-z]+\s*=|<\s*iframe\b|<\s*object\b|<\s*embed\b)',
    caseSensitive: false,
  );

  static final RegExp _sqlPayloadPattern = RegExp(
    r'(--|/\*|\*/|;\s*(drop|alter|truncate|insert|update|delete)\b|\bunion\s+select\b|\bor\s+1\s*=\s*1\b)',
    caseSensitive: false,
  );

  static final RegExp _urlPattern = RegExp(
    r'((https?:\/\/|www\.)\S+)',
    caseSensitive: false,
  );

  static final RegExp _mediaPattern = RegExp(
    r'(<\s*(img|video|source)\b|!\[[^\]]*\]\([^\)]*\)|\.(png|jpe?g|gif|webp|bmp|svg|mp4|mov|avi|wmv|webm|mkv)\b)',
    caseSensitive: false,
  );

  static final RegExp _phonePattern = RegExp(
    r'(\+?\d[\d\s\-()]{8,}\d)',
    caseSensitive: false,
  );

  static final RegExp _addressPattern = RegExp(
    r'([0-9０-９]{1,4}(丁目|番地|番|号)|都道府県|都|道|府|県|市|区|町|村)',
    caseSensitive: false,
  );

  static String normalizeText(
    String input, {
    bool allowNewLines = false,
    int maxLength = 4000,
  }) {
    var value = input;
    if (!allowNewLines) {
      value = value.replaceAll(RegExp(r'[\r\n\t]+'), ' ');
    }
    value = value.replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '');
    value = value.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    if (value.length > maxLength) {
      value = value.substring(0, maxLength);
    }
    return value;
  }

  static bool containsInjectionPayload(String value) {
    return _scriptPattern.hasMatch(value) || _sqlPayloadPattern.hasMatch(value);
  }

  static String normalizeReplyMessage(String input) {
    return normalizeText(input, allowNewLines: false, maxLength: 100);
  }

  static String? validateReplyMessage(String value) {
    if (value.runes.length > 100) {
      return '返信は100文字以内で入力してください。';
    }
    final normalized = normalizeReplyMessage(value);
    if (normalized.isEmpty) return '返信内容を入力してください。';
    if (containsInjectionPayload(normalized)) {
      return '返信に使用できない文字列が含まれています。';
    }
    if (_urlPattern.hasMatch(normalized)) {
      return 'URLは返信に含められません。';
    }
    if (_mediaPattern.hasMatch(normalized)) {
      return '画像・動画に関する内容は返信に含められません。';
    }
    if (_phonePattern.hasMatch(normalized)) {
      return '電話番号と推測される情報は返信に含められません。';
    }
    if (_addressPattern.hasMatch(normalized)) {
      return '住所と推測される情報は返信に含められません。';
    }
    return null;
  }

  static String? validateSafeText(
    String value, {
    required String fieldLabel,
    bool required = true,
    bool allowNewLines = false,
    int maxLength = 4000,
  }) {
    final normalized = normalizeText(
      value,
      allowNewLines: allowNewLines,
      maxLength: maxLength,
    );

    if (required && normalized.isEmpty) {
      return '$fieldLabelを入力してください。';
    }

    if (normalized.isEmpty) {
      return null;
    }

    if (containsInjectionPayload(normalized)) {
      return '$fieldLabelに使用できない文字列が含まれています。';
    }

    return null;
  }
}
