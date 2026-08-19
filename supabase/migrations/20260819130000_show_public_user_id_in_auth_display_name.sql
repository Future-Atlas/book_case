-- Supabase Studio does not support custom columns in Authentication > Users.
-- Include the public Sharemarium user ID in the existing Display name column
-- while retaining the username and user ID as separate metadata fields.
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
            'display_name', NEW.username || ' (@' || NEW.user_id || ')',
            'sharemarium_username', NEW.username,
            'sharemarium_user_id', NEW.user_id
        ),
        updated_at = now()
    WHERE id = NEW.id;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_profile_to_auth_metadata() FROM PUBLIC;

UPDATE auth.users AS auth_user
SET raw_user_meta_data = coalesce(auth_user.raw_user_meta_data, '{}'::jsonb)
    || jsonb_build_object(
        'display_name', profile.username || ' (@' || profile.user_id || ')',
        'sharemarium_username', profile.username,
        'sharemarium_user_id', profile.user_id
    ),
    updated_at = now()
FROM public.profiles AS profile
WHERE profile.id = auth_user.id;
