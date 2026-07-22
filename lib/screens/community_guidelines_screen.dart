import 'package:flutter/material.dart';

class CommunityGuidelinesScreen extends StatelessWidget {
  const CommunityGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('コミュニティガイドライン'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: _CommunityGuidelinesContent(),
        ),
      ),
    );
  }
}

class _CommunityGuidelinesContent extends StatelessWidget {
  const _CommunityGuidelinesContent();

  static const _titleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w900,
    height: 1.5,
  );

  static const _headingStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.7,
  );

  static const _subheadingStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.7,
  );

  static const _bodyStyle = TextStyle(
    fontSize: 13,
    height: 1.9,
    color: Colors.black87,
  );

  static const String _guidelinesText = r'''# Sharemarium コミュニティガイドライン

本ガイドラインは、読書レビューSNS「Sharemarium」（以下「本サービス」といいます。）をすべての利用者が楽しく、安全に利用できるよう定めたものです。

---

## 1. 基本的なマナー

* 相手を尊重したコミュニケーションを心がけましょう。
* 健全なレビュー、建設的なフィードバックを推奨します。

---

## 2. 禁止行為

* 著者や出版社、他のユーザーへの誹謗中傷、嫌がらせ行為。
* 著作権を侵害するような本文の丸写し、無許可転載。
* スパム行為や不正な宣伝。

---

## 3. ネタバレについて

* ネタバレを含むレビューを投稿する場合は、必ず「ネタバレあり」の設定を行ってください。

---

以上のガイドラインを遵守し、素晴らしい読書ライフをお楽しみください。''';

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(_guidelinesText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks) ...[
          if (block.spacingBefore > 0)
            SizedBox(height: block.spacingBefore),
          Padding(
            padding: EdgeInsets.only(left: block.isBullet ? 12 : 0),
            child: Text(block.text, style: block.style),
          ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  static List<_PolicyBlock> _parseBlocks(String source) {
    final blocks = <_PolicyBlock>[];
    var previousLineWasEmpty = false;

    for (final rawLine in source.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        previousLineWasEmpty = true;
        continue;
      }
      if (line == '---') {
        previousLineWasEmpty = true;
        continue;
      }

      final spacing = previousLineWasEmpty ? 12.0 : 2.0;
      previousLineWasEmpty = false;

      if (line.startsWith('# ')) {
        blocks.add(
          _PolicyBlock(
            text: line.substring(2),
            style: _titleStyle,
            spacingBefore: blocks.isEmpty ? 0 : 20,
          ),
        );
      } else if (line.startsWith('## ')) {
        blocks.add(
          _PolicyBlock(
            text: line.substring(3),
            style: _headingStyle,
            spacingBefore: blocks.isEmpty ? 0 : 20,
          ),
        );
      } else if (line.startsWith('### ')) {
        blocks.add(
          _PolicyBlock(
            text: line.substring(4),
            style: _subheadingStyle,
            spacingBefore: 12,
          ),
        );
      } else if (line.startsWith('**') && line.endsWith('**')) {
        blocks.add(
          _PolicyBlock(
            text: line.substring(2, line.length - 2),
            style: _subheadingStyle,
            spacingBefore: spacing,
          ),
        );
      } else if (line.startsWith('* ')) {
        blocks.add(
          _PolicyBlock(
            text: '• ${line.substring(2).replaceAll('**', '')}',
            style: _bodyStyle,
            spacingBefore: 0,
            isBullet: true,
          ),
        );
      } else {
        blocks.add(
          _PolicyBlock(
            text: line.replaceAll('**', ''),
            style: _bodyStyle,
            spacingBefore: spacing,
          ),
        );
      }
    }

    return blocks;
  }
}

class _PolicyBlock {
  const _PolicyBlock({
    required this.text,
    required this.style,
    required this.spacingBefore,
    this.isBullet = false,
  });

  final String text;
  final TextStyle style;
  final double spacingBefore;
  final bool isBullet;
}
