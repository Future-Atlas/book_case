CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

ALTER TABLE public.profiles
    DROP CONSTRAINT IF EXISTS profiles_username_key;

CREATE TABLE IF NOT EXISTS public.privacy_password_credentials (
    profile_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    password_hash TEXT NOT NULL,
    failed_attempts SMALLINT NOT NULL DEFAULT 0 CHECK (failed_attempts BETWEEN 0 AND 20),
    locked_until TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.privacy_password_recovery_requests (
    profile_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    provider TEXT NOT NULL,
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.privacy_password_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.privacy_password_recovery_requests ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.privacy_password_credentials FROM anon, authenticated;
REVOKE ALL ON public.privacy_password_recovery_requests FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.is_valid_privacy_password(candidate TEXT)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
    SELECT candidate IS NOT NULL
       AND char_length(candidate) BETWEEN 8 AND 20
       AND candidate ~ '[a-z]'
       AND candidate ~ '[A-Z]'
       AND candidate ~ '[0-9]';
$$;

CREATE OR REPLACE FUNCTION public.has_privacy_password()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
    SELECT auth.uid() IS NOT NULL AND EXISTS (
        SELECT 1
        FROM public.privacy_password_credentials
        WHERE profile_id = auth.uid()
    );
$$;

CREATE OR REPLACE FUNCTION public.initialize_privacy_password(p_password TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;
    IF NOT public.is_valid_privacy_password(p_password) THEN
        RAISE EXCEPTION 'Invalid privacy password' USING ERRCODE = '23514';
    END IF;
    INSERT INTO public.privacy_password_credentials (profile_id, password_hash)
    VALUES (auth.uid(), extensions.crypt(p_password, extensions.gen_salt('bf', 12)));
END;
$$;

CREATE OR REPLACE FUNCTION public.verify_privacy_password(p_password TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    credential public.privacy_password_credentials%ROWTYPE;
    next_attempts SMALLINT;
BEGIN
    IF auth.uid() IS NULL THEN RETURN false; END IF;
    SELECT * INTO credential
    FROM public.privacy_password_credentials
    WHERE profile_id = auth.uid()
    FOR UPDATE;

    IF NOT FOUND OR credential.locked_until > timezone('utc'::text, now()) THEN
        RETURN false;
    END IF;

    IF credential.password_hash = extensions.crypt(p_password, credential.password_hash) THEN
        UPDATE public.privacy_password_credentials
        SET failed_attempts = 0, locked_until = NULL
        WHERE profile_id = auth.uid();
        RETURN true;
    END IF;

    next_attempts := credential.failed_attempts + 1;
    UPDATE public.privacy_password_credentials
    SET failed_attempts = CASE WHEN next_attempts >= 5 THEN 0 ELSE next_attempts END,
        locked_until = CASE
            WHEN next_attempts >= 5 THEN timezone('utc'::text, now()) + interval '15 minutes'
            ELSE NULL
        END
    WHERE profile_id = auth.uid();
    RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_public_profile(
    p_username TEXT,
    p_user_id TEXT,
    p_is_private BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    normalized_user_id TEXT := lower(btrim(p_user_id));
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;
    IF char_length(btrim(p_username)) NOT BETWEEN 1 AND 30
       OR normalized_user_id !~ '^[a-z0-9_]{3,20}$'
       OR normalized_user_id IN (
           'admin', 'administrator', 'support', 'sharemarium', 'system', 'official'
       ) THEN
        RAISE EXCEPTION 'Invalid profile data' USING ERRCODE = '23514';
    END IF;
    UPDATE public.profiles
    SET username = btrim(p_username),
        user_id = normalized_user_id,
        is_private = p_is_private
    WHERE id = auth.uid();
END;
$$;

CREATE OR REPLACE FUNCTION public.update_private_account_details(
    p_password TEXT,
    p_full_name TEXT,
    p_birth_date DATE,
    p_phone_number TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    normalized_phone TEXT := regexp_replace(p_phone_number, '[^0-9+]', '', 'g');
BEGIN
    IF NOT public.verify_privacy_password(p_password) THEN
        RETURN false;
    END IF;
    IF char_length(btrim(p_full_name)) NOT BETWEEN 1 AND 100
       OR p_birth_date < DATE '1900-01-01'
       OR p_birth_date > CURRENT_DATE
       OR normalized_phone !~ '^\+?[0-9]{7,15}$' THEN
        RAISE EXCEPTION 'Invalid private account data' USING ERRCODE = '23514';
    END IF;
    UPDATE public.account_details
    SET full_name = btrim(p_full_name),
        birth_date = p_birth_date,
        phone_number = normalized_phone,
        phone_verified_at = CASE
            WHEN phone_number = normalized_phone THEN phone_verified_at
            ELSE NULL
        END,
        updated_at = timezone('utc'::text, now())
    WHERE profile_id = auth.uid();
    RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION public.change_privacy_password(
    p_current_password TEXT,
    p_new_password TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
    IF NOT public.is_valid_privacy_password(p_new_password) THEN
        RAISE EXCEPTION 'Invalid privacy password' USING ERRCODE = '23514';
    END IF;
    IF NOT public.verify_privacy_password(p_current_password) THEN
        RETURN false;
    END IF;
    UPDATE public.privacy_password_credentials
    SET password_hash = extensions.crypt(p_new_password, extensions.gen_salt('bf', 12)),
        failed_attempts = 0,
        locked_until = NULL,
        updated_at = timezone('utc'::text, now())
    WHERE profile_id = auth.uid();
    RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.begin_privacy_password_recovery()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_provider TEXT := auth.jwt() -> 'app_metadata' ->> 'provider';
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;
    IF current_provider NOT IN ('google', 'twitter', 'x', 'facebook', 'apple', 'discord') THEN
        RAISE EXCEPTION 'Unsupported recovery provider' USING ERRCODE = '22023';
    END IF;
    INSERT INTO public.privacy_password_recovery_requests (
        profile_id, provider, requested_at
    ) VALUES (
        auth.uid(), current_provider, timezone('utc'::text, now())
    )
    ON CONFLICT (profile_id) DO UPDATE
    SET provider = EXCLUDED.provider,
        requested_at = EXCLUDED.requested_at;
END;
$$;

CREATE OR REPLACE FUNCTION public.reset_privacy_password_after_reauthentication(
    p_new_password TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    recovery public.privacy_password_recovery_requests%ROWTYPE;
    has_recent_oauth BOOLEAN;
BEGIN
    IF NOT public.is_valid_privacy_password(p_new_password) THEN
        RAISE EXCEPTION 'Invalid privacy password' USING ERRCODE = '23514';
    END IF;
    SELECT * INTO recovery
    FROM public.privacy_password_recovery_requests
    WHERE profile_id = auth.uid()
      AND requested_at >= timezone('utc'::text, now()) - interval '15 minutes';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Recovery request expired' USING ERRCODE = '42501';
    END IF;
    IF (auth.jwt() -> 'app_metadata' ->> 'provider') IS DISTINCT FROM recovery.provider THEN
        RAISE EXCEPTION 'Recovery provider mismatch' USING ERRCODE = '42501';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM jsonb_array_elements(COALESCE(auth.jwt() -> 'amr', '[]'::jsonb)) AS entry
        WHERE entry ->> 'method' = 'oauth'
          AND to_timestamp((entry ->> 'timestamp')::double precision)
              >= recovery.requested_at - interval '5 seconds'
    ) INTO has_recent_oauth;
    IF NOT has_recent_oauth THEN
        RAISE EXCEPTION 'Fresh OAuth authentication required' USING ERRCODE = '42501';
    END IF;

    UPDATE public.privacy_password_credentials
    SET password_hash = extensions.crypt(p_new_password, extensions.gen_salt('bf', 12)),
        failed_attempts = 0,
        locked_until = NULL,
        updated_at = timezone('utc'::text, now())
    WHERE profile_id = auth.uid();
    DELETE FROM public.privacy_password_recovery_requests
    WHERE profile_id = auth.uid();
END;
$$;

DROP FUNCTION IF EXISTS public.complete_registration(TEXT, DATE, TEXT, TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.complete_registration(
    p_full_name TEXT,
    p_birth_date DATE,
    p_phone_number TEXT,
    p_username TEXT,
    p_user_id TEXT,
    p_privacy_password TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    current_profile_id UUID := auth.uid();
    normalized_user_id TEXT := lower(btrim(p_user_id));
    normalized_phone TEXT := regexp_replace(p_phone_number, '[^0-9+]', '', 'g');
BEGIN
    IF current_profile_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;
    IF char_length(btrim(p_full_name)) NOT BETWEEN 1 AND 100
       OR p_birth_date < DATE '1900-01-01'
       OR p_birth_date > CURRENT_DATE
       OR normalized_phone !~ '^\+?[0-9]{7,15}$'
       OR char_length(btrim(p_username)) NOT BETWEEN 1 AND 30
       OR normalized_user_id !~ '^[a-z0-9_]{3,20}$'
       OR NOT public.is_valid_privacy_password(p_privacy_password) THEN
        RAISE EXCEPTION 'Invalid registration data' USING ERRCODE = '23514';
    END IF;
    IF normalized_user_id IN (
        'admin', 'administrator', 'support', 'sharemarium', 'system', 'official'
    ) THEN
        RAISE EXCEPTION 'Reserved user ID' USING ERRCODE = '23514';
    END IF;

    UPDATE public.profiles
    SET username = btrim(p_username), user_id = normalized_user_id
    WHERE id = current_profile_id;

    INSERT INTO public.account_details (
        profile_id, full_name, birth_date, phone_number
    ) VALUES (
        current_profile_id, btrim(p_full_name), p_birth_date, normalized_phone
    )
    ON CONFLICT (profile_id) DO UPDATE
    SET full_name = EXCLUDED.full_name,
        birth_date = EXCLUDED.birth_date,
        phone_number = EXCLUDED.phone_number,
        phone_verified_at = CASE
            WHEN public.account_details.phone_number = EXCLUDED.phone_number
                THEN public.account_details.phone_verified_at
            ELSE NULL
        END,
        updated_at = timezone('utc'::text, now());

    INSERT INTO public.privacy_password_credentials (profile_id, password_hash)
    VALUES (
        current_profile_id,
        extensions.crypt(p_privacy_password, extensions.gen_salt('bf', 12))
    )
    ON CONFLICT (profile_id) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.is_valid_privacy_password(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.has_privacy_password() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.initialize_privacy_password(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.verify_privacy_password(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.update_public_profile(TEXT, TEXT, BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.update_private_account_details(TEXT, TEXT, DATE, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.change_privacy_password(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.begin_privacy_password_recovery() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reset_privacy_password_after_reauthentication(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.complete_registration(TEXT, DATE, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.has_privacy_password() TO authenticated;
GRANT EXECUTE ON FUNCTION public.initialize_privacy_password(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_privacy_password(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_public_profile(TEXT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_private_account_details(TEXT, TEXT, DATE, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.change_privacy_password(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.begin_privacy_password_recovery() TO authenticated;
GRANT EXECUTE ON FUNCTION public.reset_privacy_password_after_reauthentication(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_registration(TEXT, DATE, TEXT, TEXT, TEXT, TEXT) TO authenticated;

DROP POLICY IF EXISTS "Users can update their own account details" ON public.account_details;
