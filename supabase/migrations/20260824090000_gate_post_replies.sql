-- Keep paid reply access private and enforce it at the database boundary.

CREATE TABLE IF NOT EXISTS private.reply_entitlements (
    profile_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    can_reply BOOLEAN NOT NULL DEFAULT false,
    granted_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
);

REVOKE ALL ON TABLE private.reply_entitlements FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private.reply_entitlements TO service_role;

COMMENT ON TABLE private.reply_entitlements IS
    'Private feature entitlements maintained by administrators or a future billing webhook.';

CREATE OR REPLACE FUNCTION public.current_user_can_reply()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT auth.uid() IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM private.reply_entitlements AS entitlement
            WHERE entitlement.profile_id = auth.uid()
              AND entitlement.can_reply = true
       );
$$;

REVOKE ALL ON FUNCTION public.current_user_can_reply() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_can_reply() TO anon, authenticated;

DROP POLICY IF EXISTS "Public can read post replies" ON public.post_replies;
DROP POLICY IF EXISTS "Visible post replies can be read" ON public.post_replies;
CREATE POLICY "Visible post replies can be read"
    ON public.post_replies FOR SELECT TO anon, authenticated
    USING (
        public.can_view_profile_content(profile_id)
        AND EXISTS (
            SELECT 1
            FROM public.posts
            WHERE posts.id = post_replies.post_id
              AND public.can_view_profile_content(posts.profile_id)
        )
    );

DROP POLICY IF EXISTS "Authenticated users can add replies" ON public.post_replies;
DROP POLICY IF EXISTS "Entitled users can add replies" ON public.post_replies;
CREATE POLICY "Entitled users can add replies"
    ON public.post_replies FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() = profile_id
        AND public.is_profile_active(auth.uid())
        AND public.current_user_can_reply()
        AND EXISTS (
            SELECT 1
            FROM public.posts
            WHERE posts.id = post_replies.post_id
              AND public.can_view_profile_content(posts.profile_id)
        )
    );

GRANT SELECT ON public.post_replies TO anon;

COMMENT ON FUNCTION public.current_user_can_reply() IS
    'Returns whether the authenticated profile has the paid reply entitlement.';
