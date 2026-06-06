# 📚 図書管理・本棚共有アプリ（仮称）

「昔の学校の図書室」のような温かみのあるエモい演出と、本を愛するヘビー読書家のためのプロ仕様の整理機能を兼ね備えた、大人のための読書秘密基地アプリです。

既存の大手読書SNS（読書メーターやブクログなど）が持つ「賑やかなレビュー共有」とは一線を画し、**「図書カードを通じた時空を超えた静かな繋がり」**と**「15種類のマニアックな条件掛け合わせによる究極の本棚管理」**を提供します。

## 🛠️ 技術スタック (Technical Stack)

1つのソースコードでWeb、iOS、Android、すべてのプラットフォームに対応できるモダンな構成です。

| レイヤー | 採用技術 | 選定の理由・メリット |
| :--- | :--- | :--- |
| **フロントエンド** | **Flutter (Dart)** | 単一コードでWeb版からiOS/Androidアプリへのスムーズな移行を約束。 |
| **バックエンド** | **Supabase** | Firebaseに代わる高性能な無料枠。リレーショナルデータ（本の情報やユーザーの繋がり）を扱いやすい。 |
| **ホスティング** | **Vercel** | Git Pushするだけで1〜2分でWebに自動反映される快適なCI/CD環境（無料ドメイン）。 |
| **書籍データAPI** | **ハイブリッド構成** | 「楽天ブックス/Google Books API」の画像データ ＋「openBD（出版業界データ）/国会図書館」の網羅性を融合。 |

---

## ✨ コア機能 (Core Features)

1. **図書カード風の演出**
   * 本の詳細画面を開くと、昔懐かしい縦書きの「図書カード」が表示され、過去にその本を読んだユーザーの名前が静かに連なるエモい体験。
2. **プロ仕様の15種類掛け合わせ絞り込み**
   * 大手アプリにはない、マニアックな条件（既読・積読・著者・出版年・ページ数・カスタムタグなど）を最大15種類組み合わせて一瞬で本棚を整理・検索できる機能。
3. **網羅率ほぼ100%の書籍検索**
   * バーコード読み取りやおなじみのキーワード検索に加え、公共・業界データベースの巻き込みにより、マニアックな専門書や絶版本も漏れなく登録可能。

---

## 💰 マネタイズ戦略 (Monetization)

アプリの雰囲気を壊す不快なバナー広告（Google AdSense等）は初期段階では排除し、ユーザーの読書体験に寄り添った形からスタートします。

* **初期Webフェーズ:** * 成果ノルマのない**「楽天アフィリエイト」**の購入ボタンを設置。画面を汚さず、ノーリスクかつ無料ドメインのまま収益化。
* **アプリ展開フェーズ:** * ストア進出（iOS/Android）後は、高度な本棚絞り込み機能を一時的に解放する**「Google AdMob（リワード動画広告）」**などをスマートに導入予定。

---

## 📂 ディレクトリ構成 (Directory Structure)

Flutterのマルチプラットフォーム機能を活かしつつ、開発の99%は `lib` フォルダ内で行います。他のプラットフォームフォルダ（`ios`, `android` 等）は将来の拡張のためにそのままキープします。

```text
📂 book_case
 ├── 📁 web            # Web版（Vercel公開用）の土台
 ├── 📁 ios            # 将来のiOSアプリ化用（キープ）
 ├── 📁 android        # 手元の動作確認・将来のAndroid用（キープ）
 └── 📁 lib            🔥【開発のメイン】あなたがコードを書く場所
       └── 📄 main.dart  # アプリの起動エントリーポイント

---

## 🏃‍♂️ 開発の進め方 (Getting Started)

### 1. パッケージの取得
```bash
flutter pub get
```

### 2. データベース環境のセットアップ (ローカル開発環境)
本プロジェクトは、本番環境 (Supabase Cloud) と開発環境 (ローカルPC) を簡単に分離できるよう設計されています。

#### ① 必要なツールの準備
* **Docker Desktop**: 起動しておきます
* **Supabase CLI**: インストールします
  ```bash
  brew install supabase/tap/supabase
  ```

#### ② ローカルSupabaseの起動と初期スキーマ適用
```bash
# ローカルSupabaseを起動 (初回はDockerイメージ取得のため数分かかります)
supabase start
```
起動が完了すると、ターミナル上にローカル用の `Project URL` と `anon key` が表示されます。また、`supabase/migrations` に配置した初期スキーマ（シードデータを含む）がローカルDBに自動適用されます。
* **ローカルDB管理画面 (Studio)**: [http://localhost:54323](http://localhost:54323)

#### ③ ローカル環境で実行
起動時に取得したローカル用の接続キーを渡して実行します。
```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=http://localhost:54321 \
  --dart-define=SUPABASE_KEY=あなたのローカルanon_key
```
*(※ キーを指定せずに起動した場合は、自動的にメモリ内のモックデータベースモードで起動します)*

---

## 🚀 本番への公開 (Production Deployment)

### 1. Supabase Cloudの設定
1. Supabase Cloudで新規プロジェクトを作成します。
2. **SQL Editor** を開き、`supabase/schema.sql` の中身をコピー＆ペーストして実行し、スキーマとシードデータを本番DBに作成します。

### 2. Vercelのデプロイ設定
1. プロジェクトをVercelにインポートし、ダッシュボードの **Project Settings > Environment Variables** から以下の環境変数を設定します。
   * `SUPABASE_URL`: 本番のSupabase Project URL
   * `SUPABASE_ANON_KEY`: 本番のanon key
2. これにより、クローラー検知時の動的レンダリング機能（SEO対策）が完全に有効化されます。

### 3. 本番用ビルド・デバッグ
```bash
# 本番DBに繋いだ状態での実行
flutter run -d chrome \
  --dart-define=SUPABASE_URL=本番のURL \
  --dart-define=SUPABASE_KEY=本番のanon_key

# Web向けビルド生成
flutter build web --release \
  --dart-define=SUPABASE_URL=本番のURL \
  --dart-define=SUPABASE_KEY=本番のanon_key
```