-- Public profile avatars are intentionally readable by anyone because they are
-- displayed as part of a user's public Sharemarium profile.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    true,
    5242880,
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Public profile avatars are readable" ON storage.objects;
CREATE POLICY "Public profile avatars are readable"
ON storage.objects
FOR SELECT
USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Users can upload their own profile avatar" ON storage.objects;
CREATE POLICY "Users can upload their own profile avatar"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users can update their own profile avatar" ON storage.objects;
CREATE POLICY "Users can update their own profile avatar"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users can delete their own profile avatar" ON storage.objects;
CREATE POLICY "Users can delete their own profile avatar"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Four-argument overload used by current clients. The previous three-argument
-- version remains available temporarily for already-open older deployments.
CREATE OR REPLACE FUNCTION public.update_public_profile(
    p_username TEXT,
    p_user_id TEXT,
    p_bio TEXT,
    p_is_private BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    normalized_user_id TEXT := lower(btrim(p_user_id));
    normalized_bio TEXT := btrim(COALESCE(p_bio, ''));
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;
    IF char_length(btrim(p_username)) NOT BETWEEN 1 AND 30
       OR normalized_user_id !~ '^[a-z0-9_]{3,20}$'
       OR normalized_user_id IN (
           'admin', 'administrator', 'support', 'sharemarium', 'system', 'official'
       )
       OR char_length(normalized_bio) > 300 THEN
        RAISE EXCEPTION 'Invalid profile data' USING ERRCODE = '23514';
    END IF;
    UPDATE public.profiles
    SET username = btrim(p_username),
        user_id = normalized_user_id,
        bio = normalized_bio,
        is_private = p_is_private
    WHERE id = auth.uid();
END;
$$;

REVOKE ALL ON FUNCTION public.update_public_profile(TEXT, TEXT, TEXT, BOOLEAN)
    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_public_profile(TEXT, TEXT, TEXT, BOOLEAN)
    TO authenticated;
