CREATE OR REPLACE FUNCTION public.get_profile_follow_list(
    target_profile UUID,
    list_type TEXT
)
RETURNS TABLE (
    id UUID,
    username TEXT,
    user_id TEXT,
    avatar_url TEXT,
    bio TEXT,
    followers_count INTEGER,
    following_count INTEGER,
    read_count INTEGER,
    is_private BOOLEAN,
    followed_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    viewer_id UUID := auth.uid();
    target_is_private BOOLEAN;
BEGIN
    IF viewer_id IS NULL OR list_type NOT IN ('followers', 'following') THEN
        RETURN;
    END IF;

    SELECT profiles.is_private
    INTO target_is_private
    FROM public.profiles
    WHERE profiles.id = target_profile
      AND profiles.is_suspended = false;

    IF NOT FOUND
       OR public.is_blocked_between(viewer_id, target_profile)
       OR (viewer_id <> target_profile AND target_is_private) THEN
        RETURN;
    END IF;

    IF list_type = 'followers' THEN
        RETURN QUERY
        SELECT p.id, p.username, p.user_id, p.avatar_url, p.bio,
               p.followers_count, p.following_count, p.read_count,
               p.is_private, COALESCE(f.responded_at, f.requested_at)
        FROM public.follows AS f
        JOIN public.profiles AS p ON p.id = f.follower_id
        WHERE f.following_id = target_profile
          AND f.status = 'accepted'
          AND p.is_suspended = false
          AND NOT public.is_blocked_between(viewer_id, p.id)
        ORDER BY COALESCE(f.responded_at, f.requested_at) DESC;
    ELSE
        RETURN QUERY
        SELECT p.id, p.username, p.user_id, p.avatar_url, p.bio,
               p.followers_count, p.following_count, p.read_count,
               p.is_private, COALESCE(f.responded_at, f.requested_at)
        FROM public.follows AS f
        JOIN public.profiles AS p ON p.id = f.following_id
        WHERE f.follower_id = target_profile
          AND f.status = 'accepted'
          AND p.is_suspended = false
          AND NOT public.is_blocked_between(viewer_id, p.id)
        ORDER BY COALESCE(f.responded_at, f.requested_at) DESC;
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.get_profile_follow_list(UUID, TEXT)
    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_profile_follow_list(UUID, TEXT)
    TO authenticated;
