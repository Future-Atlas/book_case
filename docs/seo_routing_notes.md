# SEO URL / app route consistency notes

This project intentionally serves crawler-friendly pages for the following public routes:

- `/`
- `/book/{slug}`
- `/genre/{genre}`
- `/users/{id}`

The Flutter app keeps the same route semantics on the client side so that a human opening the URL sees the same content intent as the crawler page. The app shell maps:

- `/book/*` and `/genre/*` to the home screen content area
- `/users/*`, `/user/*`, and `/profile/*` to the profile screen

This avoids a mismatch where the crawler page exists but the app falls back to the default landing screen for the same URL.

The SEO edge function still guards private, suspended, and missing profiles by returning noindex or 404 responses instead of exposing data that should not be public.
