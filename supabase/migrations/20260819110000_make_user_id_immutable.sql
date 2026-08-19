-- A public user ID is a stable account identifier. It is selected once during
-- registration and cannot be changed through profile settings afterwards.
CREATE OR REPLACE FUNCTION public.update_public_profile(
    p_username TEXT,
    p_user_id TEXT,
    p_bio TEXT,
    p_is_private BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    normalized_user_id TEXT := lower(btrim(p_user_id));
    normalized_bio TEXT := btrim(COALESCE(p_bio, ''));
    existing_user_id TEXT;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    SELECT profile.user_id
    INTO existing_user_id
    FROM public.profiles AS profile
    WHERE profile.id = auth.uid();

    IF existing_user_id IS NULL THEN
        RAISE EXCEPTION 'Profile not found' USING ERRCODE = 'P0002';
    END IF;
    IF normalized_user_id IS DISTINCT FROM existing_user_id THEN
        RAISE EXCEPTION 'USER_ID_IMMUTABLE' USING ERRCODE = '23514';
    END IF;
    IF char_length(btrim(p_username)) NOT BETWEEN 1 AND 30
       OR char_length(normalized_bio) > 300 THEN
        RAISE EXCEPTION 'Invalid profile data' USING ERRCODE = '23514';
    END IF;

    UPDATE public.profiles
    SET username = btrim(p_username),
        bio = normalized_bio,
        is_private = p_is_private
    WHERE id = auth.uid();
END;
$$;

REVOKE ALL ON FUNCTION public.update_public_profile(TEXT, TEXT, TEXT, BOOLEAN)
    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_public_profile(TEXT, TEXT, TEXT, BOOLEAN)
    TO authenticated;

-- Retire the older overload that could still modify a user ID.
REVOKE EXECUTE ON FUNCTION public.update_public_profile(TEXT, TEXT, BOOLEAN)
    FROM authenticated;

-- Prevent direct profile-table updates to this column. Registration continues
-- to set it through the validated SECURITY DEFINER registration function.
REVOKE UPDATE (user_id) ON TABLE public.profiles FROM authenticated;
