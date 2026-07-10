-- Ensure authenticated users can create only their own profile row.
DROP POLICY IF EXISTS "Allow users to insert their own profile" ON public.profiles;

CREATE POLICY "Allow users to insert their own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);
