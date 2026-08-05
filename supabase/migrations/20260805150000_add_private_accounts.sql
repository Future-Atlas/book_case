-- Add an account-level privacy switch. Basic profile identity remains visible,
-- while posts, bookshelves and favorites are readable only when the profile is
-- public or the requester owns the profile.
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS is_private BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.profiles.is_private IS
    'When true, posts, collections and favorites are hidden from everyone except the owner.';

DROP POLICY IF EXISTS "Allow public read access for posts" ON public.posts;
DROP POLICY IF EXISTS "Allow visible profile posts to be read" ON public.posts;
CREATE POLICY "Allow visible profile posts to be read"
    ON public.posts FOR SELECT
    USING (
        auth.uid() = profile_id
        OR EXISTS (
            SELECT 1
            FROM public.profiles AS profile
            WHERE profile.id = posts.profile_id
              AND profile.is_private = false
        )
    );

DROP POLICY IF EXISTS "Allow public read access for favorites" ON public.favorites;
DROP POLICY IF EXISTS "Allow visible profile favorites to be read" ON public.favorites;
CREATE POLICY "Allow visible profile favorites to be read"
    ON public.favorites FOR SELECT
    USING (
        auth.uid() = profile_id
        OR EXISTS (
            SELECT 1
            FROM public.profiles AS profile
            WHERE profile.id = favorites.profile_id
              AND profile.is_private = false
        )
    );

DROP POLICY IF EXISTS "Allow public read access for collections" ON public.collections;
DROP POLICY IF EXISTS "Allow visible profile collections to be read" ON public.collections;
CREATE POLICY "Allow visible profile collections to be read"
    ON public.collections FOR SELECT
    USING (
        auth.uid() = profile_id
        OR EXISTS (
            SELECT 1
            FROM public.profiles AS profile
            WHERE profile.id = collections.profile_id
              AND profile.is_private = false
        )
    );
