-- Prevent users removed by an administrator from immediately registering
-- again with the same identity. Raw names, dates of birth, email addresses,
-- and phone numbers are not retained in this denial list.

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO service_role;

CREATE TABLE IF NOT EXISTS private.registration_denial_config (
    singleton BOOLEAN PRIMARY KEY DEFAULT true CHECK (singleton),
    pepper TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE
        NOT NULL DEFAULT timezone('utc'::text, now())
);

INSERT INTO private.registration_denial_config (singleton, pepper)
VALUES (true, encode(extensions.gen_random_bytes(32), 'hex'))
ON CONFLICT (singleton) DO NOTHING;

CREATE TABLE IF NOT EXISTS private.registration_denials (
    id UUID PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
    name_birth_email_hash BYTEA,
    name_birth_phone_hash BYTEA NOT NULL,
    deleted_by UUID,
    reason TEXT CHECK (reason IS NULL OR char_length(reason) <= 500),
    created_at TIMESTAMP WITH TIME ZONE
        NOT NULL DEFAULT timezone('utc'::text, now()),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CHECK (name_birth_email_hash IS NOT NULL OR name_birth_phone_hash IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS registration_denials_email_hash_idx
    ON private.registration_denials (name_birth_email_hash)
    WHERE name_birth_email_hash IS NOT NULL;
CREATE INDEX IF NOT EXISTS registration_denials_phone_hash_idx
    ON private.registration_denials (name_birth_phone_hash);
CREATE INDEX IF NOT EXISTS registration_denials_expires_at_idx
    ON private.registration_denials (expires_at);

CREATE TABLE IF NOT EXISTS private.account_deletion_exemptions (
    profile_id UUID PRIMARY KEY,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);

REVOKE ALL ON ALL TABLES IN SCHEMA private FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, DELETE ON private.registration_denials TO service_role;
GRANT SELECT, INSERT, DELETE ON private.account_deletion_exemptions TO service_role;

CREATE OR REPLACE FUNCTION private.normalize_denial_name(source TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
    SELECT lower(
        regexp_replace(
            replace(btrim(coalesce(source, '')), chr(12288), ''),
            '[[:space:]]+',
            '',
            'g'
        )
    );
$$;

CREATE OR REPLACE FUNCTION private.normalize_denial_email(source TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
    SELECT lower(btrim(coalesce(source, '')));
$$;

CREATE OR REPLACE FUNCTION private.normalize_denial_phone(source TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
    SELECT regexp_replace(coalesce(source, ''), '[^0-9]', '', 'g');
$$;

CREATE OR REPLACE FUNCTION private.registration_denial_hash(
    identifier_kind TEXT,
    full_name TEXT,
    birth_date DATE,
    identifier_value TEXT
)
RETURNS BYTEA
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = private, extensions
AS $$
DECLARE
    secret TEXT;
    normalized_identifier TEXT;
    fingerprint_source TEXT;
BEGIN
    SELECT pepper INTO secret
    FROM private.registration_denial_config
    WHERE singleton = true;

    IF identifier_kind = 'email' THEN
        normalized_identifier := private.normalize_denial_email(identifier_value);
    ELSIF identifier_kind = 'phone' THEN
        normalized_identifier := private.normalize_denial_phone(identifier_value);
    ELSE
        RAISE EXCEPTION 'Unsupported identifier kind';
    END IF;

    IF secret IS NULL OR normalized_identifier = '' THEN
        RETURN NULL;
    END IF;

    fingerprint_source := concat_ws(
        '|',
        identifier_kind,
        private.normalize_denial_name(full_name),
        birth_date::TEXT,
        normalized_identifier
    );
    RETURN extensions.hmac(
        convert_to(fingerprint_source, 'UTF8'),
        convert_to(secret, 'UTF8'),
        'sha256'
    );
END;
$$;

CREATE OR REPLACE FUNCTION private.registration_denial_matches(
    full_name TEXT,
    birth_date DATE,
    phone_number TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, private, auth, extensions
AS $$
DECLARE
    current_email TEXT;
    email_hash BYTEA;
    phone_hash BYTEA;
BEGIN
    DELETE FROM private.registration_denials
    WHERE expires_at <= timezone('utc'::text, now());

    SELECT email INTO current_email
    FROM auth.users
    WHERE id = auth.uid();

    email_hash := private.registration_denial_hash(
        'email', full_name, birth_date, current_email
    );
    phone_hash := private.registration_denial_hash(
        'phone', full_name, birth_date, phone_number
    );

    RETURN EXISTS (
        SELECT 1
        FROM private.registration_denials AS denial
        WHERE denial.expires_at > timezone('utc'::text, now())
          AND (
              (email_hash IS NOT NULL AND denial.name_birth_email_hash = email_hash)
              OR
              (phone_hash IS NOT NULL AND denial.name_birth_phone_hash = phone_hash)
          )
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.record_admin_account_deletion(
    target_profile UUID,
    deleting_admin UUID,
    deletion_reason TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, auth, extensions
AS $$
DECLARE
    details RECORD;
    denial_id UUID;
BEGIN
    IF target_profile IS NULL OR deleting_admin IS NULL OR target_profile = deleting_admin THEN
        RAISE EXCEPTION 'Invalid account deletion request' USING ERRCODE = '22023';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.app_admins WHERE profile_id = deleting_admin
    ) THEN
        RAISE EXCEPTION 'Administrator access required' USING ERRCODE = '42501';
    END IF;

    SELECT account.full_name, account.birth_date, account.phone_number, users.email
    INTO details
    FROM public.account_details AS account
    JOIN auth.users AS users ON users.id = account.profile_id
    WHERE account.profile_id = target_profile;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Account details not found' USING ERRCODE = 'P0002';
    END IF;

    DELETE FROM private.registration_denials
    WHERE expires_at <= timezone('utc'::text, now());

    INSERT INTO private.registration_denials (
        name_birth_email_hash,
        name_birth_phone_hash,
        deleted_by,
        reason,
        expires_at
    ) VALUES (
        private.registration_denial_hash(
            'email', details.full_name, details.birth_date, details.email
        ),
        private.registration_denial_hash(
            'phone', details.full_name, details.birth_date, details.phone_number
        ),
        deleting_admin,
        NULLIF(btrim(deletion_reason), ''),
        timezone('utc'::text, now()) + INTERVAL '3 years'
    ) RETURNING id INTO denial_id;

    RETURN denial_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_admin_account_deletion_record(
    denial_record UUID,
    deleting_admin UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.app_admins WHERE profile_id = deleting_admin
    ) THEN
        RAISE EXCEPTION 'Administrator access required' USING ERRCODE = '42501';
    END IF;
    DELETE FROM private.registration_denials
    WHERE id = denial_record AND deleted_by = deleting_admin;
END;
$$;

CREATE OR REPLACE FUNCTION public.prepare_self_account_deletion(
    target_profile UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
    IF target_profile IS NULL THEN
        RAISE EXCEPTION 'Invalid account deletion request' USING ERRCODE = '22023';
    END IF;
    DELETE FROM private.account_deletion_exemptions
    WHERE expires_at <= timezone('utc'::text, now());
    INSERT INTO private.account_deletion_exemptions (profile_id, expires_at)
    VALUES (
        target_profile,
        timezone('utc'::text, now()) + INTERVAL '5 minutes'
    )
    ON CONFLICT (profile_id) DO UPDATE
    SET expires_at = EXCLUDED.expires_at;
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_self_account_deletion(
    target_profile UUID
)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = private
AS $$
    DELETE FROM private.account_deletion_exemptions
    WHERE profile_id = target_profile;
$$;

CREATE OR REPLACE FUNCTION private.record_denial_before_auth_user_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, auth, extensions
AS $$
DECLARE
    details RECORD;
    self_deletion BOOLEAN := false;
    email_hash BYTEA;
    phone_hash BYTEA;
BEGIN
    DELETE FROM private.account_deletion_exemptions
    WHERE expires_at <= timezone('utc'::text, now());

    WITH removed AS (
        DELETE FROM private.account_deletion_exemptions
        WHERE profile_id = OLD.id
        RETURNING profile_id
    )
    SELECT EXISTS (SELECT 1 FROM removed) INTO self_deletion;
    IF self_deletion THEN
        RETURN OLD;
    END IF;

    SELECT full_name, birth_date, phone_number
    INTO details
    FROM public.account_details
    WHERE profile_id = OLD.id;
    IF NOT FOUND THEN
        RETURN OLD;
    END IF;

    email_hash := private.registration_denial_hash(
        'email', details.full_name, details.birth_date, OLD.email
    );
    phone_hash := private.registration_denial_hash(
        'phone', details.full_name, details.birth_date, details.phone_number
    );

    IF NOT EXISTS (
        SELECT 1
        FROM private.registration_denials AS denial
        WHERE denial.expires_at > timezone('utc'::text, now())
          AND (
              (email_hash IS NOT NULL AND denial.name_birth_email_hash = email_hash)
              OR denial.name_birth_phone_hash = phone_hash
          )
    ) THEN
        INSERT INTO private.registration_denials (
            name_birth_email_hash,
            name_birth_phone_hash,
            deleted_by,
            reason,
            expires_at
        ) VALUES (
            email_hash,
            phone_hash,
            NULL,
            'Supabase administrator deletion',
            timezone('utc'::text, now()) + INTERVAL '3 years'
        );
    END IF;
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS record_denial_before_auth_user_delete ON auth.users;
CREATE TRIGGER record_denial_before_auth_user_delete
    BEFORE DELETE ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION private.record_denial_before_auth_user_delete();

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
SET search_path = public, private, extensions
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
    IF private.registration_denial_matches(
        p_full_name, p_birth_date, normalized_phone
    ) THEN
        RAISE EXCEPTION 'REGISTRATION_DENIED' USING ERRCODE = 'P0001';
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

REVOKE ALL ON FUNCTION public.record_admin_account_deletion(UUID, UUID, TEXT)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.cancel_admin_account_deletion_record(UUID, UUID)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.prepare_self_account_deletion(UUID)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.cancel_self_account_deletion(UUID)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_admin_account_deletion(UUID, UUID, TEXT)
    TO service_role;
GRANT EXECUTE ON FUNCTION public.cancel_admin_account_deletion_record(UUID, UUID)
    TO service_role;
GRANT EXECUTE ON FUNCTION public.prepare_self_account_deletion(UUID)
    TO service_role;
GRANT EXECUTE ON FUNCTION public.cancel_self_account_deletion(UUID)
    TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_registration(TEXT, DATE, TEXT, TEXT, TEXT, TEXT)
    TO authenticated;

REVOKE ALL ON FUNCTION private.normalize_denial_name(TEXT)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.normalize_denial_email(TEXT)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.normalize_denial_phone(TEXT)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.registration_denial_hash(TEXT, TEXT, DATE, TEXT)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.registration_denial_matches(TEXT, DATE, TEXT)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.record_denial_before_auth_user_delete()
    FROM PUBLIC, anon, authenticated;

COMMENT ON TABLE private.registration_denials IS
    'Keyed, non-plaintext identity fingerprints retained for three years after an administrator deletes an account.';
