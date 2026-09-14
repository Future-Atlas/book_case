# SEO URL / app route consistency notes

This project intentionally serves crawler-friendly pages for the following public routes:

- `/`
- `/book/{slug}`
- `/genre/{genre}`
- `/users/{id}`
- `/posts` and `/posts/{post-id}` (crawler-only SSR)

The Flutter app keeps the same route semantics on the client side so that a human opening the URL sees the same content intent as the crawler page. The app shell maps:

- `/book/*` and `/genre/*` to the home screen content area
- `/users/*`, `/user/*`, and `/profile/*` to the profile screen
- `/posts` to the Flutter post index and `/posts/{post-id}` to the existing
  Flutter post detail screen, including the usual account gates

The post SSR rewrites require a crawler User-Agent, just like the other public
SEO routes. Ordinary browsers fall through to the Flutter app. The post index
conceals spoiler text and uses the existing viewer privacy/age/block filters.

After deploying, use an authenticated Vercel Preview browser session to inspect
`https://staging.sharemarium.com/posts`: with a Googlebot User-Agent, expect
HTTP 200 and `X-Posts-Diagnostics: ok`, and check that the HTML shows the staging
test post rather than production posts. With the browser default User-Agent,
expect the Flutter post index and a working link to its post detail screen.
Keep Preview deployment protection enabled. A redirected Vercel login page with
HTTP 200 is not a successful SSR check.

This avoids a mismatch where the crawler page exists but the app falls back to the default landing screen for the same URL.

The SEO edge function still guards private, suspended, and missing profiles by returning noindex or 404 responses instead of exposing data that should not be public.
