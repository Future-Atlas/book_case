-- Keep blue, yellow, and green available to every account. The complete
-- palette is available to active subscribers and users who had already set a
-- custom color before the lock was introduced.

CREATE TABLE IF NOT EXISTS private.page_color_legacy_entitlements (
    profile_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    granted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    reason TEXT NOT NULL DEFAULT 'pre_lock_custom_color'
);

REVOKE ALL ON TABLE private.page_color_legacy_entitlements
    FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private.page_color_legacy_entitlements
    TO service_role;

-- Grandfather profiles that used a non-basic color before 2026-08-30 JST.
INSERT INTO private.page_color_legacy_entitlements (profile_id)
SELECT id
FROM public.profiles
WHERE created_at < TIMESTAMPTZ '2026-08-30 00:00:00+09'
  AND page_color NOT IN ('blue', 'yellow', 'green')
ON CONFLICT (profile_id) DO NOTHING;

-- Accounts created after the lock date do not retain a premium color unless
-- an active subscription has already been granted.
UPDATE public.profiles
SET page_color = 'yellow'
WHERE created_at >= TIMESTAMPTZ '2026-08-30 00:00:00+09'
  AND page_color NOT IN ('blue', 'yellow', 'green')
  AND NOT private.profile_has_active_subscription(id);

CREATE OR REPLACE FUNCTION public.current_user_can_use_all_page_colors()
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
                FROM private.page_color_legacy_entitlements AS entitlement
                WHERE entitlement.profile_id = auth.uid()
            )
       );
$$;

REVOKE ALL ON FUNCTION public.current_user_can_use_all_page_colors()
    FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_can_use_all_page_colors()
    TO anon, authenticated;

COMMENT ON FUNCTION public.current_user_can_use_all_page_colors() IS
    'Returns whether the authenticated profile may select the complete page-color palette.';

CREATE OR REPLACE FUNCTION public.enforce_profile_page_color_entitlement()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NEW.page_color NOT IN ('blue', 'yellow', 'green')
       AND NOT (
            private.profile_has_active_subscription(NEW.id)
            OR EXISTS (
                SELECT 1
                FROM private.page_color_legacy_entitlements AS entitlement
                WHERE entitlement.profile_id = NEW.id
            )
       ) THEN
        RAISE EXCEPTION 'page_color_subscription_required'
            USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_profile_page_color_entitlement_trigger
    ON public.profiles;
CREATE TRIGGER enforce_profile_page_color_entitlement_trigger
BEFORE INSERT OR UPDATE OF page_color ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.enforce_profile_page_color_entitlement();

REVOKE ALL ON FUNCTION public.enforce_profile_page_color_entitlement()
    FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.update_profile_page_color(
    p_page_color TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    IF p_page_color IS NULL OR p_page_color NOT IN (
        'red', 'magenta', 'blue', 'yellow', 'green', 'purple', 'gray',
        'orange', 'pink', 'light_blue', 'emerald', 'red_purple',
        'yellow_green', 'brown'
    ) THEN
        RAISE EXCEPTION 'Invalid page color' USING ERRCODE = '23514';
    END IF;

    IF p_page_color NOT IN ('blue', 'yellow', 'green')
       AND NOT public.current_user_can_use_all_page_colors() THEN
        RAISE EXCEPTION 'page_color_subscription_required'
            USING ERRCODE = '42501';
    END IF;

    UPDATE public.profiles
    SET page_color = p_page_color
    WHERE id = auth.uid();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found' USING ERRCODE = 'P0002';
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.update_profile_page_color(TEXT)
    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_profile_page_color(TEXT)
    TO authenticated;
