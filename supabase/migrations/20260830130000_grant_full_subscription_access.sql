-- Permanently grant all currently subscription-gated features to the
-- designated profile when it exists in the target environment. A row in
-- subscription_entitlements unlocks replies, the 12-book favorite limit, and
-- the complete page-color palette.

INSERT INTO private.subscription_entitlements (
    profile_id,
    is_active,
    granted_at,
    expires_at,
    updated_at
)
SELECT
    profile.id,
    true,
    timezone('utc'::text, now()),
    NULL,
    timezone('utc'::text, now())
FROM public.profiles AS profile
WHERE profile.id = '5513a324-8735-43f0-996d-d6fa964faa4f'::UUID
ON CONFLICT (profile_id) DO UPDATE
SET is_active = true,
    granted_at = COALESCE(
        private.subscription_entitlements.granted_at,
        EXCLUDED.granted_at
    ),
    expires_at = NULL,
    updated_at = EXCLUDED.updated_at;
