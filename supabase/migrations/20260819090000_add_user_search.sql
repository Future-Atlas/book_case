-- Search only public identity fields. Private registration details such as
-- legal name, email address and phone number are never referenced here.
CREATE OR REPLACE FUNCTION public.search_profiles_by_public_identity(
    search_query TEXT
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
    is_private BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    viewer_id UUID := auth.uid();
    normalized_query TEXT := lower(regexp_replace(btrim(search_query), '^@', ''));
BEGIN
    IF viewer_id IS NULL
       OR char_length(normalized_query) NOT BETWEEN 1 AND 50 THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT p.id, p.username, p.user_id, p.avatar_url, p.bio,
           p.followers_count, p.following_count, p.read_count, p.is_private
    FROM public.profiles AS p
    WHERE p.is_suspended = false
      AND NOT public.is_blocked_between(viewer_id, p.id)
      AND (
          position(normalized_query IN lower(p.username)) > 0
          OR position(normalized_query IN lower(p.user_id)) > 0
      )
    ORDER BY
      CASE
        WHEN lower(p.user_id) = normalized_query THEN 0
        WHEN lower(p.username) = normalized_query THEN 1
        WHEN lower(p.user_id) LIKE normalized_query || '%' THEN 2
        WHEN lower(p.username) LIKE normalized_query || '%' THEN 3
        ELSE 4
      END,
      lower(p.username),
      p.id
    LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.search_profiles_by_public_identity(TEXT)
    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_profiles_by_public_identity(TEXT)
    TO authenticated;
