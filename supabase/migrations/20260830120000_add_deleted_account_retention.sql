-- Keep a minimal, private record of account deletion attempts for 90 days.
-- Records under an explicit legal hold are excluded from automatic deletion.

CREATE TABLE IF NOT EXISTS private.deleted_accounts (
    id UUID PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
    profile_id UUID NOT NULL,
    username TEXT,
    user_id TEXT,
    full_name TEXT,
    birth_date DATE,
    email TEXT,
    phone_number TEXT,
    auth_provider TEXT,
    deletion_type TEXT NOT NULL CHECK (deletion_type IN ('self', 'admin')),
    deletion_succeeded BOOLEAN,
    deletion_error TEXT CHECK (
        deletion_error IS NULL OR char_length(deletion_error) <= 1000
    ),
    deleted_by UUID,
    requested_at TIMESTAMP WITH TIME ZONE NOT NULL
        DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMP WITH TIME ZONE,
    handling_notes TEXT CHECK (
        handling_notes IS NULL OR char_length(handling_notes) <= 1000
    ),
    legal_hold BOOLEAN NOT NULL DEFAULT false,
    legal_hold_reason TEXT CHECK (
        legal_hold_reason IS NULL OR char_length(legal_hold_reason) <= 1000
    ),
    legal_hold_set_at TIMESTAMP WITH TIME ZONE,
    legal_hold_set_by UUID,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
        DEFAULT timezone('utc'::text, now()) + INTERVAL '90 days',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
        DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
        DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS deleted_accounts_profile_id_idx
    ON private.deleted_accounts (profile_id);
CREATE INDEX IF NOT EXISTS deleted_accounts_user_id_idx
    ON private.deleted_accounts (lower(user_id))
    WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS deleted_accounts_email_idx
    ON private.deleted_accounts (lower(email))
    WHERE email IS NOT NULL;
CREATE INDEX IF NOT EXISTS deleted_accounts_expiry_idx
    ON private.deleted_accounts (expires_at)
    WHERE legal_hold = false;

REVOKE ALL ON TABLE private.deleted_accounts
    FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private.deleted_accounts
    TO service_role;

COMMENT ON TABLE private.deleted_accounts IS
    'Private 90-day account-deletion audit records. Legal-hold records are retained until the hold is released.';

CREATE OR REPLACE FUNCTION public.prepare_deleted_account_record(
    target_profile UUID,
    deletion_kind TEXT,
    deleting_admin UUID DEFAULT NULL,
    deletion_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    audit_id UUID;
    target_user auth.users%ROWTYPE;
    profile_record RECORD;
    details_record RECORD;
BEGIN
    IF target_profile IS NULL
       OR deletion_kind NOT IN ('self', 'admin')
       OR (deletion_kind = 'admin' AND deleting_admin IS NULL)
       OR char_length(coalesce(deletion_notes, '')) > 1000 THEN
        RAISE EXCEPTION 'Invalid account deletion audit request'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO target_user
    FROM auth.users
    WHERE id = target_profile;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Auth user not found' USING ERRCODE = 'P0002';
    END IF;

    SELECT username, user_id
    INTO profile_record
    FROM public.profiles
    WHERE id = target_profile;

    SELECT full_name, birth_date, phone_number
    INTO details_record
    FROM public.account_details
    WHERE profile_id = target_profile;

    INSERT INTO private.deleted_accounts (
        profile_id,
        username,
        user_id,
        full_name,
        birth_date,
        email,
        phone_number,
        auth_provider,
        deletion_type,
        deleted_by,
        handling_notes
    ) VALUES (
        target_profile,
        profile_record.username,
        profile_record.user_id,
        details_record.full_name,
        details_record.birth_date,
        target_user.email,
        details_record.phone_number,
        target_user.raw_app_meta_data ->> 'provider',
        deletion_kind,
        CASE
            WHEN deletion_kind = 'self' THEN target_profile
            ELSE deleting_admin
        END,
        NULLIF(btrim(deletion_notes), '')
    )
    RETURNING id INTO audit_id;

    RETURN audit_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.finalize_deleted_account_record(
    audit_record UUID,
    succeeded BOOLEAN,
    failure_message TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF audit_record IS NULL
       OR succeeded IS NULL
       OR char_length(coalesce(failure_message, '')) > 1000 THEN
        RAISE EXCEPTION 'Invalid account deletion audit result'
            USING ERRCODE = '22023';
    END IF;

    UPDATE private.deleted_accounts
    SET deletion_succeeded = succeeded,
        deletion_error = CASE
            WHEN succeeded THEN NULL
            ELSE NULLIF(left(failure_message, 1000), '')
        END,
        deleted_at = CASE
            WHEN succeeded THEN timezone('utc'::text, now())
            ELSE NULL
        END,
        expires_at = timezone('utc'::text, now()) + INTERVAL '90 days',
        updated_at = timezone('utc'::text, now())
    WHERE id = audit_record;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Account deletion audit record not found'
            USING ERRCODE = 'P0002';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_deleted_account_legal_hold(
    audit_record UUID,
    hold_enabled BOOLEAN,
    hold_reason TEXT,
    acting_admin UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF audit_record IS NULL
       OR hold_enabled IS NULL
       OR acting_admin IS NULL
       OR (hold_enabled AND btrim(coalesce(hold_reason, '')) = '')
       OR char_length(coalesce(hold_reason, '')) > 1000 THEN
        RAISE EXCEPTION 'Invalid legal hold request' USING ERRCODE = '22023';
    END IF;

    UPDATE private.deleted_accounts
    SET legal_hold = hold_enabled,
        legal_hold_reason = CASE
            WHEN hold_enabled THEN btrim(hold_reason)
            ELSE NULL
        END,
        legal_hold_set_at = CASE
            WHEN hold_enabled THEN timezone('utc'::text, now())
            ELSE NULL
        END,
        legal_hold_set_by = CASE
            WHEN hold_enabled THEN acting_admin
            ELSE NULL
        END,
        updated_at = timezone('utc'::text, now())
    WHERE id = audit_record;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Account deletion audit record not found'
            USING ERRCODE = 'P0002';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION private.purge_expired_deleted_accounts()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM private.deleted_accounts
    WHERE legal_hold = false
      AND expires_at <= timezone('utc'::text, now());
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;

REVOKE ALL ON FUNCTION public.prepare_deleted_account_record(UUID, TEXT, UUID, TEXT)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.finalize_deleted_account_record(UUID, BOOLEAN, TEXT)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.set_deleted_account_legal_hold(UUID, BOOLEAN, TEXT, UUID)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.purge_expired_deleted_accounts()
    FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.prepare_deleted_account_record(UUID, TEXT, UUID, TEXT)
    TO service_role;
GRANT EXECUTE ON FUNCTION public.finalize_deleted_account_record(UUID, BOOLEAN, TEXT)
    TO service_role;
GRANT EXECUTE ON FUNCTION public.set_deleted_account_legal_hold(UUID, BOOLEAN, TEXT, UUID)
    TO service_role;
GRANT EXECUTE ON FUNCTION private.purge_expired_deleted_accounts()
    TO service_role;

-- Supabase supports pg_cron for scheduled database maintenance. Run the
-- cleanup daily; legal-hold records are deliberately ignored.
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;

DO $$
DECLARE
    existing_job BIGINT;
BEGIN
    FOR existing_job IN
        SELECT jobid
        FROM cron.job
        WHERE jobname = 'purge-expired-deleted-accounts'
    LOOP
        PERFORM cron.unschedule(existing_job);
    END LOOP;

    PERFORM cron.schedule(
        'purge-expired-deleted-accounts',
        '17 3 * * *',
        'SELECT private.purge_expired_deleted_accounts();'
    );
END;
$$;
