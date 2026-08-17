ALTER TABLE public.account_details
    ADD COLUMN IF NOT EXISTS guardian_consent_declared_at TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS guardian_consent_terms_version TEXT;

DROP FUNCTION IF EXISTS public.complete_registration(TEXT, DATE, TEXT, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.complete_registration(
    p_full_name TEXT,
    p_birth_date DATE,
    p_phone_number TEXT,
    p_username TEXT,
    p_user_id TEXT,
    p_privacy_password TEXT,
    p_guardian_consent BOOLEAN,
    p_terms_version TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, extensions
AS $$
DECLARE
    current_profile_id UUID := auth.uid();
    normalized_user_id TEXT := lower(btrim(p_user_id));
    normalized_phone TEXT := regexp_replace(p_phone_number, '[^0-9+]', '', 'g');
    is_minor BOOLEAN := p_birth_date > (CURRENT_DATE - INTERVAL '18 years')::date;
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
       OR NOT public.is_valid_privacy_password(p_privacy_password)
       OR char_length(btrim(p_terms_version)) NOT BETWEEN 1 AND 50 THEN
        RAISE EXCEPTION 'Invalid registration data' USING ERRCODE = '23514';
    END IF;
    IF is_minor AND NOT COALESCE(p_guardian_consent, false) THEN
        RAISE EXCEPTION 'GUARDIAN_CONSENT_REQUIRED' USING ERRCODE = '23514';
    END IF;
    IF normalized_user_id IN (
        'admin', 'administrator', 'support', 'sharemarium', 'system', 'official'
    ) THEN
        RAISE EXCEPTION 'Reserved user ID' USING ERRCODE = '23514';
    END IF;
    IF private.registration_denial_matches(
        p_full_name, p_birth_date, normalized_phone
    ) THEN
        RAISE EXCEPTION 'REGISTRATION_DENIED' USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.profiles
    SET username = btrim(p_username), user_id = normalized_user_id
    WHERE id = current_profile_id;

    INSERT INTO public.account_details (
        profile_id,
        full_name,
        birth_date,
        phone_number,
        guardian_consent_declared_at,
        guardian_consent_terms_version
    ) VALUES (
        current_profile_id,
        btrim(p_full_name),
        p_birth_date,
        normalized_phone,
        CASE WHEN is_minor THEN timezone('utc'::text, now()) ELSE NULL END,
        CASE WHEN is_minor THEN btrim(p_terms_version) ELSE NULL END
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
        guardian_consent_declared_at = EXCLUDED.guardian_consent_declared_at,
        guardian_consent_terms_version = EXCLUDED.guardian_consent_terms_version,
        updated_at = timezone('utc'::text, now());

    INSERT INTO public.privacy_password_credentials (profile_id, password_hash)
    VALUES (
        current_profile_id,
        extensions.crypt(p_privacy_password, extensions.gen_salt('bf', 12))
    )
    ON CONFLICT (profile_id) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.complete_registration(
    TEXT, DATE, TEXT, TEXT, TEXT, TEXT, BOOLEAN, TEXT
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_registration(
    TEXT, DATE, TEXT, TEXT, TEXT, TEXT, BOOLEAN, TEXT
) TO authenticated;

COMMENT ON COLUMN public.account_details.guardian_consent_declared_at IS
    'Time when a minor declared that their legal guardian had consented.';
COMMENT ON COLUMN public.account_details.guardian_consent_terms_version IS
    'Terms version shown when the guardian consent declaration was recorded.';

CREATE OR REPLACE FUNCTION public.declare_guardian_consent(
    p_terms_version TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_profile_id UUID := auth.uid();
    registered_birth_date DATE;
BEGIN
    IF current_profile_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;
    IF char_length(btrim(p_terms_version)) NOT BETWEEN 1 AND 50 THEN
        RAISE EXCEPTION 'Invalid terms version' USING ERRCODE = '23514';
    END IF;

    SELECT birth_date INTO registered_birth_date
    FROM public.account_details
    WHERE profile_id = current_profile_id;

    IF registered_birth_date IS NULL THEN
        RAISE EXCEPTION 'Registration details required' USING ERRCODE = '23514';
    END IF;
    IF registered_birth_date <= (CURRENT_DATE - INTERVAL '18 years')::date THEN
        RETURN;
    END IF;

    UPDATE public.account_details
    SET guardian_consent_declared_at = timezone('utc'::text, now()),
        guardian_consent_terms_version = btrim(p_terms_version),
        updated_at = timezone('utc'::text, now())
    WHERE profile_id = current_profile_id;
END;
$$;

REVOKE ALL ON FUNCTION public.declare_guardian_consent(TEXT)
    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.declare_guardian_consent(TEXT)
    TO authenticated;
