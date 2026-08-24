-- Keep the reply limit aligned with the UI: 100 non-whitespace characters.

ALTER TABLE public.post_replies
    DROP CONSTRAINT IF EXISTS post_replies_message_length_check;

ALTER TABLE public.post_replies
    ADD CONSTRAINT post_replies_message_length_check
    CHECK (
        char_length(regexp_replace(message, '[[:space:]]', '', 'g'))
            BETWEEN 1 AND 100
        AND char_length(message) <= 500
    );
