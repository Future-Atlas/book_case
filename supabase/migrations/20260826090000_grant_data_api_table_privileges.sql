-- Explicitly grant Data API roles the table privileges required before RLS
-- policies are evaluated. Supabase local CLI no longer implicitly exposes
-- public schema tables in the same way, so these grants make the intended
-- public-read and authenticated-write policies effective in CI and production.

GRANT SELECT ON public.profiles TO anon, authenticated;
GRANT SELECT ON public.posts TO anon, authenticated;
GRANT SELECT ON public.favorites TO anon, authenticated;
GRANT SELECT ON public.collections TO anon, authenticated;

GRANT INSERT ON public.profiles TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.posts TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.favorites TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.collections TO authenticated;
