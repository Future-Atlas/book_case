# BookCase

> A premium **Flutter** application for iOS, Android, and Web that showcases books, lets users write reviews, and stores data in **Supabase (PostgreSQL)**. The web version is hosted on **Vercel** with SEO‑friendly routing.

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
- **Flutter** (stable channel) – UI framework.
- **supabase_flutter ^2.14.1** – Supabase client.
- **provider ^6.1.2** – State management.
- **google_fonts ^6.2.1** – Premium typography.
- **flutter_dotenv ^5.0.2** – Load `.env` variables.
- **Vercel** – Hosting for the web build.
- **Supabase CLI** – Local database & API.

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
3. **Start Supabase locally** (requires Docker)
   ```bash
   supabase start
   ```
   This launches Studio, REST, GraphQL, Edge Functions and the Postgres instance.
4. **Create `.env`** (copy from example) and fill in the keys:
   ```bash
   cp .env.example .env
   ```
   ```text
   # .env (local development)
   SUPABASE_URL = http://127.0.0.1:54321
   SUPABASE_ANON_KEY = sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH
   ```
5. **Run the app**
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
- Insert seed data or use the mock data defined in `lib/services/supabase_service.dart` for quick testing.

---

## Running the App
The entry point (`lib/main.dart`) now loads variables via `flutter_dotenv`:
```dart
await dotenv.load(fileName: '.env');
final supabaseUrl = dotenv.get('SUPABASE_URL', fallback: '');
final supabaseKey = dotenv.get('SUPABASE_ANON_KEY', fallback: '');
await supabaseService.initialize(url: supabaseUrl, anonKey: supabaseKey);
```
When the keys are present, the service falls back to **real Supabase**; otherwise it uses the built‑in mock objects.

---

## Deploying to Vercel (Production)
1. **Add environment variables in Vercel** (Project Settings → Environment Variables → Production):
   - `SUPABASE_URL` – e.g. `https://your‑project.supabase.co`
   - `SUPABASE_ANON_KEY` – the publishable key from the Supabase console.
2. **GitHub Actions workflow** (`.github/workflows/deploy.yaml`) builds the web app with the keys via `--dart-define` and deploys to Vercel automatically on `main` pushes.
3. **Vercel configuration** – `vercel.json` contains rewrites that send crawler user‑agents to the SEO edge function (`/api/seo.js`).
4. After the workflow finishes, visit the Vercel URL; you’ll see live data from the **cloud Supabase** instance.

---

## Project Structure
```
book_case/
├─ .env               ← local env (git‑ignored)
├─ .env.example       ← template for collaborators
├─ lib/
│   ├─ main.dart
│   ├─ services/
│   │   └─ supabase_service.dart   ← real + mock logic
│   └─ screens/
│       ├─ book_list_screen.dart
│       └─ user_profile_screen.dart
├─ supabase/
│   ├─ migrations/20260606144325_init_schema.sql
│   └─ schema.sql        ← full schema + seed data
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
|----------|------------|---------|
| `SUPABASE_URL` | Supabase project URL (local or cloud) | `http://127.0.0.1:54321` or `https://xyz.supabase.co` |
| `SUPABASE_ANON_KEY` | Publishable (anon) key – **use the value that starts with `sb_publishable_`** | `sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH` |

Both variables are loaded with `flutter_dotenv` and also passed to Vercel builds via `--dart-define`.

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

*Happy coding! 🚀*