import 'package:flutter/material.dart';

class ExternalTransmissionScreen extends StatelessWidget {
  const ExternalTransmissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('外部送信に関する公表事項'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: _ExternalTransmissionContent(),
        ),
      ),
    );
  }
}

class _ExternalTransmissionContent extends StatelessWidget {
  const _ExternalTransmissionContent();

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

  static const _minorHeadingStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.7,
    color: Colors.white,
  );

  static const _bodyStyle = TextStyle(
    fontSize: 13,
    height: 1.9,
    color: Colors.white,
  );

  static const String _disclosureText = r'''# Sharemarium 外部送信に関する公表事項

伊能龍之介（以下「運営者」といいます。）は、運営者が提供する読書レビューSNS「Sharemarium」（以下「本サービス」といいます。）において、電気通信事業法その他の法令に基づき、利用者の端末から外部事業者へ送信される情報について、以下のとおり公表します。

---

## 1. 外部送信について

本サービスでは、次の目的のため、利用者の端末に保存された情報又は利用者の端末で生成された情報が、外部事業者へ送信されることがあります。

* 本サービスの提供及び運営
* 利用者の登録及び認証
* 不正登録及び不正アクセスの防止
* 利用状況の分析
* サービス品質及び利便性の向上
* 不具合及び障害の調査
* セキュリティ対策
* 広告の配信及び広告効果の測定
* 不正な広告表示又はクリックの防止
* その他、本サービスの適切かつ安全な運営に必要な目的

運営者は、外部送信によって取得した情報を、本公表事項及びプライバシーポリシーに記載した目的の範囲で利用します。

外部事業者が受信した情報については、当該外部事業者の利用規約、プライバシーポリシーその他の規程に基づいて取り扱われる場合があります。

---

## 2. アクセス解析

### 情報を取り扱う事業者

Google LLC

### 送信される情報

* Cookieその他の識別子
* 利用者又は端末を識別するための識別子
* IPアドレス
* ブラウザの種類及びバージョン
* OSの種類及びバージョン
* 端末の種類及び設定
* 使用言語
* アクセス日時
* 閲覧したページ又は画面
* ページのタイトル及びURL
* リファラー（参照元URL）
* 画面遷移
* クリックその他の操作履歴
* 検索及び絞り込み等の利用状況
* セッションの継続時間
* エラー及び動作状況
* IPアドレス等から推定される国又はおおよその地域
* その他、利用状況の分析に必要な情報

運営者は、電話番号、レビュー本文、コメント本文その他利用者を直接特定し得る情報を、アクセス解析のための情報として意図的に送信しないよう設定及び運用します。

### 運営者における利用目的

* 本サービスの利用状況の把握
* 閲覧数及び利用傾向の分析
* 機能及び画面構成の改善
* 不具合及び障害の調査
* 本サービスの品質及び利便性の向上
* 統計情報の作成

### 外部事業者における利用目的

* アクセス解析機能の提供
* 利用状況の測定及び分析
* サービスの提供、維持及び改善
* 不正利用及びセキュリティ上の問題の検知
* 当該事業者の利用規約及びプライバシーポリシーに定める目的

---

## 3. 広告配信及び広告効果測定

### 情報を取り扱う事業者

Google LLC

### 送信される情報

* Cookieその他の識別子
* 広告識別子
* IPアドレス
* ブラウザの種類及びバージョン
* OSの種類及びバージョン
* 端末の種類及び設定
* 使用言語
* 閲覧したページ又は画面
* ページのURL
* リファラー（参照元URL）
* 広告の表示日時
* 表示された広告に関する情報
* 広告の表示回数
* 広告のクリックその他の操作情報
* IPアドレス等から推定される国又はおおよその地域
* 広告配信、不正利用防止及び効果測定に必要な情報
* その他、広告配信に必要な利用状況に関する情報

運営者は、電話番号、レビュー本文、コメント本文その他利用者を直接特定し得る情報を、広告の配信又は広告効果測定のための情報として意図的に送信しません。

### 運営者における利用目的

* 本サービス上での広告配信
* 広告の表示回数及び広告効果の測定
* 広告収益の集計
* 不正な広告表示又はクリックの検知及び防止
* 法令、利用者の設定及び必要な同意に応じた広告の表示
* 本サービスの継続的な提供及び運営

### 外部事業者における利用目的

* 広告の配信及び表示
* 広告の表示回数の調整
* 広告効果の測定
* 不正なクリックその他の不正利用の検知及び防止
* 利用者の設定及び適用される条件に応じた広告のパーソナライズ
* 広告サービスの提供、維持及び改善
* 当該事業者の利用規約及びプライバシーポリシーに定める目的

利用者が広告のパーソナライズを制限又は無効化している場合であっても、閲覧中のページの内容、おおよその地域その他の情報に基づく広告が表示されることがあります。

---

## 4. 利用者認証及び不正利用防止

### 情報を取り扱う事業者

Google LLC

### 送信される情報

#### 電話番号による認証を利用する場合

* 電話番号
* SMS認証の要求に関する情報
* 認証結果
* 認証用の識別子及びトークン
* 利用者を識別するための識別子
* IPアドレス
* ブラウザ、OS及び端末に関する情報
* 認証を行った日時
* スパム、ボットその他の不正利用の検知に必要な情報

#### Googleアカウントによるログインを利用する場合

* Googleアカウントの識別子
* メールアドレス
* 表示名
* プロフィール画像
* 利用者が提供を許可した情報
* 認証用の識別子及びトークン
* IPアドレス
* ブラウザ、OS及び端末に関する情報
* 登録又はログインを行った日時
* 不正利用の検知に必要な情報

#### 不正登録等の防止機能を利用する場合

* IPアドレス
* Cookieその他の識別子
* ブラウザ、OS及び端末に関する情報
* 使用言語
* アクセス日時
* 閲覧ページ及びリファラー
* クリックその他の操作情報
* 登録又は認証の要求に関する情報
* スパム、ボット、自動操作その他の不正利用の判定に必要な情報

運営者は、利用者のGoogleアカウントのパスワードを取得しません。

### 運営者における利用目的

* 本サービスへの利用登録
* 利用者の認証及びログイン
* 電話番号の確認
* 一人の利用者による大量のアカウント作成の防止
* なりすまし及び不正ログインの防止
* ボット及び自動操作の検知
* スパム及び不正登録の防止
* アカウントの安全管理
* 利用規約違反及び不正利用への対応
* 本サービス及び利用者の安全の確保

### 外部事業者における利用目的

* 利用者認証及びSMS認証機能の提供
* 認証要求の処理
* アクセスが人によるものか、自動的なプログラムによるものかの判定
* 不正アクセス、スパム、ボット及び不正利用の検知及び防止
* サービスの提供、維持、保護及び改善
* 当該事業者の利用規約及びプライバシーポリシーに定める目的

電話番号認証のために利用者が入力した電話番号は、認証処理及び不正利用防止等のため、外部事業者へ送信され、保存される場合があります。

---

## 5. Xアカウントによるログイン

### 情報を取り扱う事業者

X Corp.

### 送信される情報

* Xアカウントの識別子
* X上のユーザー名
* 表示名
* プロフィール画像
* メールアドレスその他利用者が提供を許可した情報
* 認証要求及び認証結果に関する情報
* 認証用の識別子及びトークン
* IPアドレス
* ブラウザ、OS及び端末に関する情報
* 登録又はログインを行った日時
* セキュリティ及び不正利用防止に必要な情報

運営者は、利用者のXアカウントのパスワードを取得しません。

### 運営者における利用目的

* 本サービスへの利用登録
* 利用者の認証及びログイン
* アカウントの作成及び管理
* なりすまし及び不正ログインの防止
* 利用規約違反及び不正利用への対応

### 外部事業者における利用目的

* ログイン及び認証機能の提供
* 認証要求の処理
* サービスの運営、保護及び改善
* 不正アクセス及び不正利用の検知及び防止
* 当該事業者の利用規約及びプライバシーポリシーに定める目的

---

## 6. Cookie等の無効化及び広告設定

利用者は、ブラウザ又は端末の設定により、Cookieの保存を拒否し、保存済みのCookieを削除し、又は広告識別子の利用を制限できる場合があります。

また、広告配信事業者が提供する広告設定を利用して、広告のパーソナライズを制限又は無効化できる場合があります。

Cookie等を無効化した場合であっても、広告自体は表示される場合があります。

Cookie等を無効化した場合、次の機能の全部又は一部が正常に利用できなくなることがあります。

* ログイン状態の維持
* 利用者認証
* セキュリティ機能
* 設定内容の保存
* アクセス解析
* 広告の表示及び表示回数の調整
* その他、Cookie等を必要とする機能

---

## 7. 外部事業者における情報の取扱い

外部事業者へ送信された情報は、各外部事業者の利用規約、プライバシーポリシー、Cookieポリシーその他の規程に従って取り扱われます。

外部事業者は、日本国外において情報を保存又は処理する場合があります。

運営者は、外部事業者のサービスを利用する場合、利用目的、送信される情報、安全管理の状況その他の事情を考慮し、適切な事業者及びサービスを選定するよう努めます。

---

## 8. 本公表事項の変更

運営者は、法令の制定若しくは改廃、本サービスの内容変更、利用する外部サービスの追加、変更若しくは廃止その他必要がある場合、本公表事項を変更することがあります。

変更後の内容及び効力発生日は、本サービス上への掲載その他適切な方法により公表します。

利用者に重大な影響又は不利益を与える変更については、緊急又はやむを得ない場合を除き、原則として効力発生日の30日前までに公表又は通知します。

法令上、利用者の同意が必要となる変更又は外部送信については、変更後の取扱いを開始する前に、運営者所定の方法により必要な同意を取得します。

---

## 9. お問い合わせ

本公表事項又は外部送信に関するお問い合わせは、本サービス上のお問い合わせフォームからご連絡ください。

**運営者**
伊能龍之介

**サービス名**
Sharemarium

**お問い合わせ方法**
本サービス上のお問い合わせフォーム

---

## 附則

**制定日**
2026年7月25日

**運営者**
伊能龍之介''';

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(_disclosureText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks) ...[
          if (block.spacingBefore > 0) SizedBox(height: block.spacingBefore),
          Padding(
            padding: EdgeInsets.only(left: block.leftPadding),
            child: Text(
              block.text,
              style: block.style.copyWith(color: Colors.white),
            ),
          ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  static List<_DisclosureBlock> _parseBlocks(String source) {
    final blocks = <_DisclosureBlock>[];
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

      final spacing = previousLineWasEmpty ? 10.0 : 2.0;
      previousLineWasEmpty = false;

      if (line.startsWith('# ')) {
        blocks.add(
          _DisclosureBlock(
            text: line.substring(2),
            style: _titleStyle,
            spacingBefore: blocks.isEmpty ? 0 : 20,
          ),
        );
      } else if (line.startsWith('## ')) {
        blocks.add(
          _DisclosureBlock(
            text: line.substring(3),
            style: _headingStyle,
            spacingBefore: blocks.isEmpty ? 0 : 20,
          ),
        );
      } else if (line.startsWith('### ')) {
        blocks.add(
          _DisclosureBlock(
            text: line.substring(4),
            style: _subheadingStyle,
            spacingBefore: 12,
          ),
        );
      } else if (line.startsWith('#### ')) {
        blocks.add(
          _DisclosureBlock(
            text: line.substring(5),
            style: _minorHeadingStyle,
            spacingBefore: 10,
            leftPadding: 8,
          ),
        );
      } else if (line.startsWith('**') && line.endsWith('**')) {
        blocks.add(
          _DisclosureBlock(
            text: line.substring(2, line.length - 2),
            style: _subheadingStyle,
            spacingBefore: spacing,
          ),
        );
      } else if (line.startsWith('* ')) {
        blocks.add(
          _DisclosureBlock(
            text: '• ${line.substring(2).replaceAll('**', '')}',
            style: _bodyStyle,
            spacingBefore: 0,
            leftPadding: 12,
          ),
        );
      } else {
        blocks.add(
          _DisclosureBlock(
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

class _DisclosureBlock {
  const _DisclosureBlock({
    required this.text,
    required this.style,
    required this.spacingBefore,
    this.leftPadding = 0,
  });

  final String text;
  final TextStyle style;
  final double spacingBefore;
  final double leftPadding;
}
