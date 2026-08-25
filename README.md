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

- Cross‑platform UI built with **Flutter** (Web-first, with iOS / Android support planned but not yet production-targeted).
- **Supabase** backend for authentication, storage, and Postgres data.
- Premium design: Google Fonts, dark / light themes, responsive layout.
- SEO‑optimized web build using a Vercel Edge Function that serves static HTML to crawlers.
- Public browsing remains available for read-only content while write actions require an authenticated user.

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
4. **Create a local runtime define file from the template**
   ```bash
   cp env.example.json env.json
   ```
   Update the values for your local Supabase instance, then run:
   ```bash
   flutter run -d chrome \
     --dart-define-from-file=env.json
   ```
5. **Start Supabase locally** (requires Docker)
   ```bash
   supabase start
   ```
   This launches Studio, REST, GraphQL, Edge Functions and the Postgres instance.
6. **Run the app**
   ```bash
   flutter run -d chrome \
     --dart-define-from-file=env.json
   ```
   You should see `Supabase initialized successfully.` in the console and real data from the local Supabase tables.

> `env.json` is intentionally not tracked by Git; keep it local only.

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
await supabaseService.initialize(
  url: supabaseUrl,
  anonKey: supabaseKey,
  redirectUrl: AppEnvironmentConfig.supabaseRedirectUrl,
);
```

The app is intentionally web-first and read-only public browsing is available even without login. Write actions remain behind authenticated checks and Supabase RLS.

---

## Deploying to Vercel (Production / Staging)

The repository uses GitHub Environments to separate deployment secrets:

- `production`
- `staging`

1. **Add environment variables in GitHub** → repository settings → Environments:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_REDIRECT_URL`
   - `VERCEL_ORG_ID`
   - `VERCEL_PROJECT_ID`
   - `VERCEL_TOKEN`
2. **CI checks** are enforced in `.github/workflows/ci.yaml` for pull requests and pushes to `main` / `develop`.
3. **Production deployment** is triggered by `.github/workflows/deploy.yaml` on `main` with the `production` environment.
4. **Staging deployment** is triggered by `.github/workflows/deploy-staging.yaml` on `develop` with the `staging` environment.
5. **Rakuten API secret handling**: web clients call `/api/rakuten` (server-side proxy), so `RAKUTEN_ACCESS_KEY` is not embedded into Flutter web bundles.
6. **Vercel configuration** – `vercel.json` contains rewrites that send crawler user‑agents to the SEO edge function (`/api/seo.js`).

> The project currently treats `develop` as the long-lived staging branch and preview target, which keeps the setup simpler for a personal project without adding an extra deployment topology.

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

| Variable | Description | Example |
| --- | --- | --- |
| `APP_ENV` | Runtime environment label | `production`, `staging`, `development` |
| `SUPABASE_URL` | Supabase project URL | `http://127.0.0.1:54321` or `https://xyz.supabase.co` |
| `SUPABASE_ANON_KEY` | Publishable anon key | `sb_publishable_...` |
| `SUPABASE_REDIRECT_URL` | OAuth redirect URL | `https://www.sharemarium.com/` |
| `RAKUTEN_APP_ID` | Rakuten API application id used by server-side proxy | `xxxxxxxx` |
| `RAKUTEN_ACCESS_KEY` | Rakuten API access key used by server-side proxy | `xxxxxxxx` |
| `RAKUTEN_REFERER` | Origin used for Rakuten requests | `https://www.sharemarium.com/` |

Runtime variables are passed via `--dart-define` or `--dart-define-from-file` and read by `String.fromEnvironment`.

### Local env file example

```bash
cp env.example.json env.json
flutter run -d chrome \
  --dart-define-from-file=env.json
```

`env.json` must stay local and is intentionally excluded from Git.

### Environment Separation (Production / Staging)

- Runtime config is switched by `APP_ENV` in `lib/config/app_environment.dart`.
- Production deploy: `.github/workflows/deploy.yaml` on `main` with `APP_ENV=production`.
- Staging deploy: `.github/workflows/deploy-staging.yaml` on `develop` with `APP_ENV=staging`.
- The repo now treats environment secrets as GitHub Environment-scoped values.

### GitHub protection steps

See [docs/github_branch_protection.md](docs/github_branch_protection.md) for the required repository settings.

### Current platform status

- Production target: Web
- iOS / Android: in development, not yet production-targeted

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

# Vercel API tests
npm ci
npm run test:api

# Supabase migration and RLS tests (requires Docker)
supabase test db

# Deploy (GitHub) – automatically runs on push to main
# You can trigger manually with:
git push origin main
```

---

## License

MIT License – see `LICENSE` file.

---

_Happy coding! 🚀_
