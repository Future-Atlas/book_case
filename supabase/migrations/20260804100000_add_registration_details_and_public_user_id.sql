-- Keep legal-name and contact data separate from publicly readable profiles.
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS user_id TEXT;

UPDATE public.profiles
SET user_id = 'reader_' || left(replace(id::text, '-', ''), 10)
WHERE user_id IS NULL OR btrim(user_id) = '';

ALTER TABLE public.profiles
    ALTER COLUMN user_id SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS profiles_user_id_lower_unique
    ON public.profiles (lower(user_id));

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'profiles_user_id_format_check'
          AND conrelid = 'public.profiles'::regclass
    ) THEN
        ALTER TABLE public.profiles
            ADD CONSTRAINT profiles_user_id_format_check
            CHECK (
                user_id = lower(user_id)
                AND user_id ~ '^[a-z0-9_]{3,20}$'
            );
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.account_details (
    profile_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL CHECK (char_length(btrim(full_name)) BETWEEN 1 AND 100),
    birth_date DATE NOT NULL CHECK (
        birth_date >= DATE '1900-01-01'
        AND birth_date <= CURRENT_DATE
    ),
    phone_number TEXT NOT NULL CHECK (phone_number ~ '^\+?[0-9]{7,15}$'),
    phone_verified_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.account_details ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read their own account details"
    ON public.account_details FOR SELECT
    TO authenticated
    USING (auth.uid() = profile_id);

CREATE POLICY "Users can insert their own account details"
    ON public.account_details FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = profile_id);

CREATE POLICY "Users can update their own account details"
    ON public.account_details FOR UPDATE
    TO authenticated
    USING (auth.uid() = profile_id)
    WITH CHECK (auth.uid() = profile_id);

GRANT SELECT, INSERT, UPDATE ON public.account_details TO authenticated;

CREATE OR REPLACE FUNCTION public.complete_registration(
    p_full_name TEXT,
    p_birth_date DATE,
    p_phone_number TEXT,
    p_username TEXT,
    p_user_id TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    current_profile_id UUID := auth.uid();
    normalized_user_id TEXT := lower(btrim(p_user_id));
    normalized_phone TEXT := regexp_replace(p_phone_number, '[^0-9+]', '', 'g');
BEGIN
    IF current_profile_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    IF char_length(btrim(p_full_name)) NOT BETWEEN 1 AND 100 THEN
        RAISE EXCEPTION 'Invalid full name' USING ERRCODE = '23514';
    END IF;

    IF p_birth_date < DATE '1900-01-01' OR p_birth_date > CURRENT_DATE THEN
        RAISE EXCEPTION 'Invalid birth date' USING ERRCODE = '23514';
    END IF;

    IF normalized_phone !~ '^\+?[0-9]{7,15}$' THEN
        RAISE EXCEPTION 'Invalid phone number' USING ERRCODE = '23514';
    END IF;

    IF char_length(btrim(p_username)) NOT BETWEEN 1 AND 30 THEN
        RAISE EXCEPTION 'Invalid username' USING ERRCODE = '23514';
    END IF;

    IF normalized_user_id !~ '^[a-z0-9_]{3,20}$' THEN
        RAISE EXCEPTION 'Invalid user ID' USING ERRCODE = '23514';
    END IF;

    IF normalized_user_id IN (
        'admin', 'administrator', 'support', 'sharemarium', 'system', 'official'
    ) THEN
        RAISE EXCEPTION 'Reserved user ID' USING ERRCODE = '23514';
    END IF;

    UPDATE public.profiles
    SET username = btrim(p_username),
        user_id = normalized_user_id
    WHERE id = current_profile_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found' USING ERRCODE = 'P0002';
    END IF;

    INSERT INTO public.account_details (
        profile_id,
        full_name,
        birth_date,
        phone_number
    ) VALUES (
        current_profile_id,
        btrim(p_full_name),
        p_birth_date,
        normalized_phone
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
END;
$$;

REVOKE ALL ON FUNCTION public.complete_registration(TEXT, DATE, TEXT, TEXT, TEXT)
    FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.complete_registration(TEXT, DATE, TEXT, TEXT, TEXT)
    TO authenticated;
