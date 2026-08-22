class InputSecurityService {
  static final RegExp _scriptPattern = RegExp(
    r'(<\s*/?\s*script\b|javascript:|on[a-z]+\s*=|<\s*iframe\b|<\s*object\b|<\s*embed\b)',
    caseSensitive: false,
  );

  static final RegExp _sqlPayloadPattern = RegExp(
    r'(--|/\*|\*/|;\s*(drop|alter|truncate|insert|update|delete)\b|\bunion\s+select\b|\bor\s+1\s*=\s*1\b)',
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
