-- Only completed, real Auth users may appear in public user search.
-- This excludes legacy seed profiles and profiles left behind mid-registration.
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
SET search_path = ''
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
      AND EXISTS (
          SELECT 1
          FROM auth.users AS auth_user
          WHERE auth_user.id = p.id
      )
      AND EXISTS (
          SELECT 1
          FROM public.account_details AS details
          WHERE details.profile_id = p.id
      )
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

-- Keep the Supabase Auth display name and public ID metadata aligned with the
-- Sharemarium profile. These values are informational and are never used for
-- authorization or RLS decisions.
CREATE OR REPLACE FUNCTION public.sync_profile_to_auth_metadata()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    UPDATE auth.users
    SET raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
        || jsonb_build_object(
            'display_name', NEW.username,
            'sharemarium_username', NEW.username,
            'sharemarium_user_id', NEW.user_id
        ),
        updated_at = now()
    WHERE id = NEW.id;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_profile_to_auth_metadata() FROM PUBLIC;

DROP TRIGGER IF EXISTS sync_profile_to_auth_metadata_trigger
    ON public.profiles;
CREATE TRIGGER sync_profile_to_auth_metadata_trigger
AFTER INSERT OR UPDATE OF username, user_id ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.sync_profile_to_auth_metadata();

-- Backfill existing Auth users so the Dashboard reflects current profiles.
UPDATE auth.users AS auth_user
SET raw_user_meta_data = coalesce(auth_user.raw_user_meta_data, '{}'::jsonb)
    || jsonb_build_object(
        'display_name', profile.username,
        'sharemarium_username', profile.username,
        'sharemarium_user_id', profile.user_id
    ),
    updated_at = now()
FROM public.profiles AS profile
WHERE profile.id = auth_user.id;
