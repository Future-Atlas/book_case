-- Create replies through one database boundary so entitlement and visibility
-- checks are applied consistently before the insert.

CREATE OR REPLACE FUNCTION public.create_post_reply(
    target_post UUID,
    reply_message TEXT
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

    INSERT INTO public.post_replies (post_id, profile_id, message)
    VALUES (target_post, actor, reply_message)
    RETURNING id INTO created_reply_id;

    RETURN created_reply_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_post_reply(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_post_reply(UUID, TEXT) TO authenticated;

COMMENT ON FUNCTION public.create_post_reply(UUID, TEXT) IS
    'Creates a timeline reply after validating authentication, entitlement, account state, and target visibility.';
