-- PostgreSQL does not interpret the double-escaped JavaScript-style patterns
-- used by the original reply constraints as intended. Replace them with
-- POSIX-compatible patterns that do not require backslash escapes.

ALTER TABLE public.post_replies
    DROP CONSTRAINT IF EXISTS post_replies_message_no_media_check;

ALTER TABLE public.post_replies
    ADD CONSTRAINT post_replies_message_no_media_check
    CHECK (
        message !~* '(<[[:space:]]*(img|video|source)([[:space:]>])|[.](png|jpe?g|gif|webp|bmp|svg|mp4|mov|avi|wmv|webm|mkv)([^[:alnum:]_]|$))'
    );

ALTER TABLE public.post_replies
    DROP CONSTRAINT IF EXISTS post_replies_message_no_phone_check;

ALTER TABLE public.post_replies
    ADD CONSTRAINT post_replies_message_no_phone_check
    CHECK (
        message !~* '([+]?[0-9][0-9[:space:]()_-]{8,}[0-9])'
    );

-- Force PostgreSQL to compile both expressions while applying the migration,
-- rather than discovering an invalid pattern on the first user reply.
DO $$
BEGIN
    PERFORM '' ~* '(<[[:space:]]*(img|video|source)([[:space:]>])|[.](png|jpe?g|gif|webp|bmp|svg|mp4|mov|avi|wmv|webm|mkv)([^[:alnum:]_]|$))';
    PERFORM '' ~* '([+]?[0-9][0-9[:space:]()_-]{8,}[0-9])';
END;
$$;
