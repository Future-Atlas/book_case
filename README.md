# Sharemarium

> Sharemarium is a premium **Flutter** application for iOS, Android, and Web that showcases books, lets users write reviews, and stores data in **Supabase (PostgreSQL)**. The web version is hosted on **Vercel** with SEO‑friendly routing.

---

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Getting Started (Local Development)](#getting-started-local-development)
- [Supabase Setup](#supabase-setup)
- [Running the App](#running-the-app)
- [Deploying to Vercel (Production)](#deploying-to-vercel-production)
- [Project Structure](#project-structure)
- [Environment Variables](#environment-variables)
- [Useful Commands](#useful-commands)
- [License](#license)

---

## Features

- Cross‑platform UI built with **Flutter** (single codebase for iOS, Android, Web).
- **Supabase** backend for authentication, storage, and Postgres data.
- Premium design: Google Fonts, glass‑morphism style, dark / light themes, responsive layout.
- SEO‑optimized web build using a Vercel Edge Function that serves static HTML to crawlers.
- Mock data fallback for rapid prototyping, automatically switched off when valid Supabase credentials are present.

---

## Tech Stack

- **Flutter 3.44.9** (stable channel) – UI framework.
- **supabase_flutter ^2.17.2** – Supabase client.
- **provider ^6.1.2** – State management.
- **google_fonts ^6.0.0** – Premium typography.
- **Vercel** – Hosting for the web build.
- **Supabase CLI 2.111.0** – Local database & API.

---

## Getting Started (Local Development)

1. **Clone the repo**
   ```bash
   git clone <repo-url>
   cd book_case
   ```
2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```
3. **Install the pinned Supabase CLI** (requires npm)
   ```bash
   npm install
   ```
4. **Start Supabase locally** (requires Docker)
   ```bash
   supabase start
   ```
   This launches Studio, REST, GraphQL, Edge Functions and the Postgres instance.
5. **Create local runtime define file** from template and fill values:
   - `env.example.json`
   - or `env.staging.example.json` / `env.production.example.json`
6. **Run the app**
   ```bash
   flutter run -d chrome   # web
   # or
   flutter run              # iOS / Android emulator
   ```
   You should see `Supabase initialized successfully.` in the console and real data from the local Supabase tables.

---

## Supabase Setup

- The repository already contains the migration file `supabase/migrations/20260606144325_init_schema.sql` which creates the following tables:
  - `profiles`
  - `books`
  - `posts`
  - `favorites`
  - `collections`
- To apply the migration (if you reset the DB):
  ```bash
  supabase db reset   # drops & recreates the DB
  supabase db push    # runs the migration scripts
  ```
- `supabase db reset` reads `supabase/seed.sql` after migrations. Add deterministic local seed data there when needed.
- Source of truth is `supabase/migrations/*.sql`. Treat `supabase/schema.sql` as an optional snapshot artifact only.

---

## Running the App

The entry point (`lib/main.dart`) reads runtime variables with `String.fromEnvironment`:

```dart
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');
await supabaseService.initialize(url: supabaseUrl, anonKey: supabaseKey);
```

When the keys are present, the service falls back to **real Supabase**; otherwise it uses the built‑in mock objects.

---

## Deploying to Vercel (Production)

1. **Add environment variables in Vercel** (Project Settings → Environment Variables → Production):
   - `SUPABASE_URL` – e.g. `https://your‑project.supabase.co`
   - `SUPABASE_ANON_KEY` – the publishable key from the Supabase console.
2. **GitHub Actions workflow** (`.github/workflows/deploy.yaml`) runs `flutter analyze` and `flutter test`, then builds/deploys on `main` pushes.
3. **Rakuten API secret handling**: web clients call `/api/rakuten` (server-side proxy), so `RAKUTEN_ACCESS_KEY` is not embedded into Flutter web bundles.
4. **Vercel configuration** – `vercel.json` contains rewrites that send crawler user‑agents to the SEO edge function (`/api/seo.js`).
5. After the workflow finishes, visit the Vercel URL; you’ll see live data from the **cloud Supabase** instance.

---

## Project Structure

```
book_case/
├─ env.example.json
├─ env.staging.example.json
├─ env.production.example.json
├─ lib/
│   ├─ main.dart
│   ├─ services/
│   │   └─ supabase_service.dart   ← real + mock logic
│   └─ screens/
│       ├─ book_list_screen.dart
│       └─ user_profile_screen.dart
├─ supabase/
│   ├─ migrations/20260606144325_init_schema.sql
│   ├─ seed.sql          ← local reset seed data
│   └─ schema.sql        ← optional snapshot (not canonical source)
├─ web/
│   └─ index.html       ← SEO meta tags
├─ api/
│   └─ seo.js           ← Edge function for crawlers
├─ vercel.json          ← Vercel rewrites & output config
├─ .github/workflows/deploy.yaml
└─ pubspec.yaml
```

---

## Environment Variables

| Variable                 | Description                                                                   | Example                                               |
| ------------------------ | ----------------------------------------------------------------------------- | ----------------------------------------------------- |
| `APP_ENV`                | App runtime environment label                                                 | `production`, `staging`, `development`                |
| `SUPABASE_URL`           | Supabase project URL (local or cloud)                                         | `http://127.0.0.1:54321` or `https://xyz.supabase.co` |
| `SUPABASE_ANON_KEY`      | Publishable (anon) key – **use the value that starts with `sb_publishable_`** | `sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH`      |
| `SUPABASE_REDIRECT_URL`  | OAuth redirect URL for auth providers                                         | `https://www.sharemarium.com/`                        |
| `RAKUTEN_PROXY_BASE_URL` | Optional absolute base URL for Rakuten proxy when app and API are split       | `https://api.sharemarium.com`                         |

Runtime variables are passed via `--dart-define` and read by `String.fromEnvironment`.

### Environment Separation (Production / Staging)

- Runtime config is switched by `APP_ENV` (read in `lib/config/app_environment.dart`).
- Production deploy: `.github/workflows/deploy.yaml` (push to `main`) with `APP_ENV=production`.
- Staging deploy: `.github/workflows/deploy-staging.yaml` (push to `develop`) with `APP_ENV=staging`.
- Example define files:
  - `env.production.example.json`
  - `env.staging.example.json`

Recommended setup in GitHub:

1. Create branch `develop` and use it for staging validation releases.
2. Add repository secrets for both workflows:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_REDIRECT_URL`
   - `RAKUTEN_APP_ID`
   - `RAKUTEN_ACCESS_KEY`
   - `RAKUTEN_REFERER`
   - `VERCEL_ORG_ID`
   - `VERCEL_PROJECT_ID`
   - `VERCEL_TOKEN`
3. Create a GitHub Environment named `production-database`, add required reviewers, and keep production database secrets scoped to it.
4. Protect `main` in Settings -> Branches: require pull requests, require the `CI / flutter` status check, require the `production-database` environment for database deployment, and disallow direct pushes.

Local build examples:

```bash
# production-like build
flutter build web --release \
   --dart-define=APP_ENV=production \
   --dart-define=SUPABASE_URL=https://your-prod-project.supabase.co \
   --dart-define=SUPABASE_ANON_KEY=sb_publishable_xxx \
   --dart-define=SUPABASE_REDIRECT_URL=https://www.sharemarium.com/

# staging-like build
flutter build web --release \
   --dart-define=APP_ENV=staging \
   --dart-define=SUPABASE_URL=https://your-staging-project.supabase.co \
   --dart-define=SUPABASE_ANON_KEY=sb_publishable_xxx \
   --dart-define=SUPABASE_REDIRECT_URL=https://staging.sharemarium.com/
```

---

## Useful Commands

```bash
# Supabase local commands
supabase start          # launch all services
supabase stop           # stop services
supabase status         # view URLs & keys (publishable key is what you need)
supabase db reset       # drop & recreate DB
supabase db push        # apply migrations

# Flutter
flutter clean
flutter pub get
flutter run -d chrome   # web dev
flutter build web        # production build

# Deploy (GitHub) – automatically runs on push to main
# You can trigger manually with:
git push origin main
```

---

## License

MIT License – see `LICENSE` file.

---

_Happy coding! 🚀_
