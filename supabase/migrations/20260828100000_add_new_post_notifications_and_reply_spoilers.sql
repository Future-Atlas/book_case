-- Notify accepted followers about new posts and support spoiler-hidden replies.

ALTER TABLE public.post_replies
    ADD COLUMN IF NOT EXISTS has_spoiler BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.notifications
    DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications
    ADD CONSTRAINT notifications_type_check
    CHECK (
        type IN (
            'reaction',
            'follow',
            'follow_request',
            'reply',
            'new_post'
        )
    );

ALTER TABLE public.notifications
    DROP CONSTRAINT IF EXISTS notifications_check1;
ALTER TABLE public.notifications
    ADD CONSTRAINT notifications_check1
    CHECK (
        (
            type IN ('reaction', 'new_post')
            AND post_id IS NOT NULL
            AND reply_id IS NULL
        )
        OR (
            type = 'reply'
            AND post_id IS NOT NULL
            AND reply_id IS NOT NULL
        )
        OR (
            type IN ('follow', 'follow_request')
            AND post_id IS NULL
            AND reply_id IS NULL
        )
    );

DROP FUNCTION IF EXISTS public.create_post_reply(UUID, TEXT, BIGINT);
CREATE OR REPLACE FUNCTION public.create_post_reply(
    target_post UUID,
    reply_message TEXT,
    target_reply BIGINT DEFAULT NULL,
    reply_has_spoiler BOOLEAN DEFAULT FALSE
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
        message,
        has_spoiler
    )
    VALUES (
        target_post,
        actor,
        target_reply,
        reply_message,
        COALESCE(reply_has_spoiler, FALSE)
    )
    RETURNING id INTO created_reply_id;

    RETURN created_reply_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_post_reply(UUID, TEXT, BIGINT, BOOLEAN)
    FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_post_reply(UUID, TEXT, BIGINT, BOOLEAN)
    TO authenticated;

CREATE OR REPLACE FUNCTION public.create_new_post_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.notifications (
        recipient_id,
        actor_id,
        type,
        post_id
    )
    SELECT
        follow.follower_id,
        NEW.profile_id,
        'new_post',
        NEW.id
    FROM public.follows AS follow
    WHERE follow.following_id = NEW.profile_id
      AND follow.status = 'accepted'
      AND follow.follower_id <> NEW.profile_id
      AND NOT public.is_blocked_between(
          follow.follower_id,
          NEW.profile_id
      );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS posts_create_follower_notification ON public.posts;
CREATE TRIGGER posts_create_follower_notification
AFTER INSERT ON public.posts
FOR EACH ROW EXECUTE FUNCTION public.create_new_post_notification();

REVOKE ALL ON FUNCTION public.create_new_post_notification() FROM PUBLIC;

COMMENT ON COLUMN public.post_replies.has_spoiler IS
    'True when the reply body must be hidden until the viewer reveals it.';
COMMENT ON FUNCTION public.create_new_post_notification() IS
    'Creates a new_post notification for every accepted follower.';
