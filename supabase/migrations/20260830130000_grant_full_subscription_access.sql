-- Permanently grant all currently subscription-gated features to the
-- designated profile. A row in subscription_entitlements unlocks replies,
-- the 12-book favorite limit, and the complete page-color palette.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE id = '5513a324-8735-43f0-996d-d6fa964faa4f'::UUID
    ) THEN
        RAISE EXCEPTION 'Profile 5513a324-8735-43f0-996d-d6fa964faa4f not found';
    END IF;
END;
$$;

INSERT INTO private.subscription_entitlements (
    profile_id,
    is_active,
    granted_at,
    expires_at,
    updated_at
)
VALUES (
    '5513a324-8735-43f0-996d-d6fa964faa4f'::UUID,
    true,
    timezone('utc'::text, now()),
    NULL,
    timezone('utc'::text, now())
)
ON CONFLICT (profile_id) DO UPDATE
SET is_active = true,
    granted_at = COALESCE(
        private.subscription_entitlements.granted_at,
        EXCLUDED.granted_at
    ),
    expires_at = NULL,
    updated_at = EXCLUDED.updated_at;
