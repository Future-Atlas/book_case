-- Limit favorites to 3 for standard accounts and 12 for active subscribers.
-- Existing favorites are preserved; the limit is enforced only on new inserts.

CREATE TABLE IF NOT EXISTS private.subscription_entitlements (
    profile_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    is_active BOOLEAN NOT NULL DEFAULT false,
    granted_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
);

REVOKE ALL ON TABLE private.subscription_entitlements
    FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private.subscription_entitlements
    TO service_role;

COMMENT ON TABLE private.subscription_entitlements IS
    'Private subscription entitlements maintained by administrators or a future billing webhook.';

CREATE OR REPLACE FUNCTION private.profile_has_active_subscription(
    target_profile_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM private.subscription_entitlements AS entitlement
        WHERE entitlement.profile_id = target_profile_id
          AND entitlement.is_active = true
          AND (
              entitlement.expires_at IS NULL
              OR entitlement.expires_at > timezone('utc'::text, now())
          )
    );
$$;

REVOKE ALL ON FUNCTION private.profile_has_active_subscription(UUID)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.profile_has_active_subscription(UUID)
    TO service_role;

CREATE OR REPLACE FUNCTION public.current_user_favorite_limit()
RETURNS INTEGER
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT CASE
        WHEN auth.uid() IS NOT NULL
         AND private.profile_has_active_subscription(auth.uid())
            THEN 12
        ELSE 3
    END;
$$;

REVOKE ALL ON FUNCTION public.current_user_favorite_limit() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_favorite_limit()
    TO anon, authenticated;

COMMENT ON FUNCTION public.current_user_favorite_limit() IS
    'Returns the authenticated profile favorite limit: 3 normally or 12 with an active subscription.';

CREATE OR REPLACE FUNCTION public.enforce_favorites_limit()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
    favorite_limit INTEGER := 3;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext(NEW.profile_id::text)::bigint);

    IF NOT EXISTS (
        SELECT 1
        FROM public.posts
        WHERE profile_id = NEW.profile_id
          AND book_id = NEW.book_id
    ) THEN
        RAISE EXCEPTION 'favorite_requires_post'
            USING ERRCODE = 'P0001';
    END IF;

    IF private.profile_has_active_subscription(NEW.profile_id) THEN
        favorite_limit := 12;
    END IF;

    IF (
        SELECT count(*)
        FROM public.favorites
        WHERE profile_id = NEW.profile_id
    ) >= favorite_limit THEN
        RAISE EXCEPTION 'favorite_limit_reached'
            USING ERRCODE = 'P0001',
                  DETAIL = format('favorite_limit=%s', favorite_limit);
    END IF;

    RETURN NEW;
END;
$$;

-- An active subscription also unlocks replies. Keep the existing individual
-- reply entitlement as a backwards-compatible administrator override.
CREATE OR REPLACE FUNCTION public.current_user_can_reply()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT auth.uid() IS NOT NULL
       AND (
            private.profile_has_active_subscription(auth.uid())
            OR EXISTS (
                SELECT 1
                FROM private.reply_entitlements AS entitlement
                WHERE entitlement.profile_id = auth.uid()
                  AND entitlement.can_reply = true
            )
       );
$$;

REVOKE ALL ON FUNCTION public.current_user_can_reply() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_can_reply()
    TO anon, authenticated;

COMMENT ON FUNCTION public.current_user_can_reply() IS
    'Returns whether the authenticated profile has an active subscription or an individual reply entitlement.';
