-- Add threaded replies and notify post owners when a new reply is created.

ALTER TABLE public.post_replies
    ADD COLUMN IF NOT EXISTS parent_reply_id BIGINT
        REFERENCES public.post_replies(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS post_replies_parent_created_idx
    ON public.post_replies (parent_reply_id, created_at ASC);

ALTER TABLE public.notifications
    ADD COLUMN IF NOT EXISTS reply_id BIGINT
        REFERENCES public.post_replies(id) ON DELETE CASCADE;

ALTER TABLE public.notifications
    DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications
    ADD CONSTRAINT notifications_type_check
    CHECK (type IN ('reaction', 'follow', 'follow_request', 'reply'));

ALTER TABLE public.notifications
    DROP CONSTRAINT IF EXISTS notifications_check1;
ALTER TABLE public.notifications
    ADD CONSTRAINT notifications_check1
    CHECK (
        (type = 'reaction' AND post_id IS NOT NULL AND reply_id IS NULL)
        OR (type = 'reply' AND post_id IS NOT NULL AND reply_id IS NOT NULL)
        OR (
            type IN ('follow', 'follow_request')
            AND post_id IS NULL
            AND reply_id IS NULL
        )
    );

DROP FUNCTION IF EXISTS public.create_post_reply(UUID, TEXT);
CREATE OR REPLACE FUNCTION public.create_post_reply(
    target_post UUID,
    reply_message TEXT,
    target_reply BIGINT DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    actor UUID := auth.uid();
    created_reply_id BIGINT;
BEGIN
    IF actor IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Authentication is required';
    END IF;

    IF NOT public.is_profile_active(actor) THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Account is not active';
    END IF;

    IF NOT public.current_user_can_reply() THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Reply entitlement is required';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.posts AS post
        WHERE post.id = target_post
          AND public.can_view_profile_content(post.profile_id)
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Target post is not available';
    END IF;

    IF target_reply IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM public.post_replies AS parent
        WHERE parent.id = target_reply
          AND parent.post_id = target_post
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23503',
            MESSAGE = 'Parent reply is not available';
    END IF;

    INSERT INTO public.post_replies (
        post_id,
        profile_id,
        parent_reply_id,
        message
    )
    VALUES (target_post, actor, target_reply, reply_message)
    RETURNING id INTO created_reply_id;

    RETURN created_reply_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_post_reply(UUID, TEXT, BIGINT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_post_reply(UUID, TEXT, BIGINT)
    TO authenticated;

CREATE OR REPLACE FUNCTION public.create_reply_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    post_owner UUID;
BEGIN
    SELECT post.profile_id
    INTO post_owner
    FROM public.posts AS post
    WHERE post.id = NEW.post_id;

    IF post_owner IS NOT NULL AND post_owner <> NEW.profile_id THEN
        INSERT INTO public.notifications (
            recipient_id,
            actor_id,
            type,
            post_id,
            reply_id
        )
        VALUES (
            post_owner,
            NEW.profile_id,
            'reply',
            NEW.post_id,
            NEW.id
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS post_replies_create_notification
    ON public.post_replies;
CREATE TRIGGER post_replies_create_notification
AFTER INSERT ON public.post_replies
FOR EACH ROW EXECUTE FUNCTION public.create_reply_notification();

REVOKE ALL ON FUNCTION public.create_reply_notification() FROM PUBLIC;

-- Preserve the notification behavior for replies created immediately before
-- this migration was applied.
INSERT INTO public.notifications (
    recipient_id,
    actor_id,
    type,
    post_id,
    reply_id,
    created_at
)
SELECT
    post.profile_id,
    reply.profile_id,
    'reply',
    reply.post_id,
    reply.id,
    reply.created_at
FROM public.post_replies AS reply
JOIN public.posts AS post ON post.id = reply.post_id
WHERE post.profile_id <> reply.profile_id
  AND NOT EXISTS (
      SELECT 1
      FROM public.notifications AS notification
      WHERE notification.type = 'reply'
        AND notification.reply_id = reply.id
  );

COMMENT ON COLUMN public.post_replies.parent_reply_id IS
    'Optional parent reply used to render a conversation thread.';
COMMENT ON COLUMN public.notifications.reply_id IS
    'Target reply for reply notifications.';
