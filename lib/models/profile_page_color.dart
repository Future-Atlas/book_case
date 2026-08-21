import 'package:flutter/material.dart';

class ProfilePageColorOption {
  const ProfilePageColorOption({
    required this.key,
    required this.label,
    required this.lightColor,
    required this.darkColor,
  });

  final String key;
  final String label;
  final Color lightColor;
  final Color darkColor;

  Color resolve(Brightness brightness) =>
      brightness == Brightness.dark ? darkColor : lightColor;
}

class ProfilePageColors {
  const ProfilePageColors._();

  static const String defaultKey = 'yellow';

  static const List<ProfilePageColorOption> options = [
    ProfilePageColorOption(
      key: 'red',
      label: '赤',
      lightColor: Color(0xFFD00303),
      darkColor: Color(0xFFFF3B30),
    ),
    ProfilePageColorOption(
      key: 'magenta',
      label: 'マゼンタ',
      lightColor: Color(0xFFB0006F),
      darkColor: Color(0xFFFF2CB3),
    ),
    ProfilePageColorOption(
      key: 'blue',
      label: '青',
      lightColor: Color(0xFF005BBB),
      darkColor: Color(0xFF2D9CFF),
    ),
    ProfilePageColorOption(
      key: 'yellow',
      label: '黄色',
      lightColor: Color(0xFF9B7B00),
      darkColor: Color(0xFFF1D600),
    ),
    ProfilePageColorOption(
      key: 'green',
      label: '緑',
      lightColor: Color(0xFF007A46),
      darkColor: Color(0xFF00C875),
    ),
    ProfilePageColorOption(
      key: 'purple',
      label: '紫',
      lightColor: Color(0xFF6A1FA2),
      darkColor: Color(0xFFA855F7),
    ),
    ProfilePageColorOption(
      key: 'gray',
      label: 'グレー',
      lightColor: Color(0xFF5C6470),
      darkColor: Color(0xFFAAB2BD),
    ),
    ProfilePageColorOption(
      key: 'orange',
      label: 'オレンジ',
      lightColor: Color(0xFFC45100),
      darkColor: Color(0xFFFF7A1A),
    ),
    ProfilePageColorOption(
      key: 'pink',
      label: '桃色',
      lightColor: Color(0xFFC2185B),
      darkColor: Color(0xFFFF5CA8),
    ),
    ProfilePageColorOption(
      key: 'light_blue',
      label: '水色',
      lightColor: Color(0xFF007A9E),
      darkColor: Color(0xFF36CFFF),
    ),
    ProfilePageColorOption(
      key: 'emerald',
      label: 'エメラルド',
      lightColor: Color(0xFF00745F),
      darkColor: Color(0xFF00C9A7),
    ),
    ProfilePageColorOption(
      key: 'red_purple',
      label: '赤紫',
      lightColor: Color(0xFF8E185D),
      darkColor: Color(0xFFD94E9B),
    ),
    ProfilePageColorOption(
      key: 'yellow_green',
      label: '黄緑',
      lightColor: Color(0xFF5A8500),
      darkColor: Color(0xFF9BD600),
    ),
    ProfilePageColorOption(
      key: 'brown',
      label: '茶色',
      lightColor: Color(0xFF7A4820),
      darkColor: Color(0xFFC9854B),
    ),
  ];

  static bool isValidKey(String? key) =>
      options.any((option) => option.key == key);

  static String normalizeKey(String? key) =>
      isValidKey(key) ? key! : defaultKey;

  static Color colorFor(String? key, Brightness brightness) {
    final normalized = normalizeKey(key);
    return options
        .firstWhere((option) => option.key == normalized)
        .resolve(brightness);
  }
}
