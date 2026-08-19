-- Supabase Studio derives its Display name from several OAuth metadata keys.
-- Keep the common name keys aligned with the public Sharemarium identity so
-- provider-specific names (for example, the X account name) do not win.
CREATE OR REPLACE FUNCTION public.sync_profile_to_auth_metadata()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    public_display_name TEXT :=
        NEW.username || ' (@' || NEW.user_id || ')';
BEGIN
    UPDATE auth.users
    SET raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
        || jsonb_build_object(
            'display_name', public_display_name,
            'name', public_display_name,
            'full_name', public_display_name,
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
        'name', profile.username || ' (@' || profile.user_id || ')',
        'full_name', profile.username || ' (@' || profile.user_id || ')',
        'sharemarium_username', profile.username,
        'sharemarium_user_id', profile.user_id
    ),
    updated_at = now()
FROM public.profiles AS profile
WHERE profile.id = auth_user.id;
