-- Store spoiler state independently from the review text.
ALTER TABLE public.posts
    ADD COLUMN IF NOT EXISTS is_spoiler BOOLEAN NOT NULL DEFAULT false;

-- Preserve spoiler behavior for posts created with the legacy text prefix.
UPDATE public.posts
SET is_spoiler = true
WHERE ltrim(comment) LIKE '[ネタバレあり]%';

COMMENT ON COLUMN public.posts.is_spoiler IS
    'When true, clients conceal the review body from other users until they explicitly reveal it.';
