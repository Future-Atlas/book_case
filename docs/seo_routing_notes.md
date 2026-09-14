# SEO URL / app route consistency notes

Sharemarium uses Flutter for the human-facing web app and Vercel Serverless
Functions for crawler-friendly HTML where static metadata/indexable content is
needed.

## Canonical public route families

The general crawler-aware routes include:

- `/`
- `/book/{id}`
- `/genre/{genre}`
- `/users/{id}`
- public legal/information pages

`/users/{id}` is the canonical public profile family. Legacy `/user/{id}` and
`/profile/{id}` routes redirect to `/users/{id}`.

The Flutter app keeps compatible route semantics so a human opening a canonical
URL sees the same content intent as the crawler representation.

## Public posts: current state

On the current `develop` branch, `vercel.json` rewrites:

- `/posts` -> `/api/posts-seo`
- `/posts/{postId}` -> `/api/post-seo?post_id={postId}`

Those two rewrites are currently unconditional, so they serve the SSR renderer to
both crawlers and ordinary browsers.

A separate pending PR changes the post routes to the intended target model:

```text
crawler -> SSR
human   -> Flutter
```

Do not document the split as active production behavior until that PR is merged
and the Vercel/Supabase runtime environment has been verified.

## Indexing boundaries

Crawler rendering and sitemap generation must not expose content that is not
publicly indexable. In particular, private, suspended, deleted, missing, empty,
or otherwise restricted content should return an appropriate 404/noindex result
or be omitted from the sitemap.

Crawler HTML and the Flutter page for the same canonical URL should describe the
same public resource. SSR exists to make that resource understandable to
crawlers, not to create a separate content model.
