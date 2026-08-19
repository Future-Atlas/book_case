-- Enforce user ID immutability at the table boundary as well. Initial
-- registration is allowed because account_details does not exist yet.
CREATE OR REPLACE FUNCTION public.enforce_profile_user_id_immutability()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NEW.user_id IS DISTINCT FROM OLD.user_id
       AND EXISTS (
           SELECT 1
           FROM public.account_details AS details
           WHERE details.profile_id = OLD.id
       )
       AND COALESCE(auth.role(), '') <> 'service_role' THEN
        RAISE EXCEPTION 'USER_ID_IMMUTABLE' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.enforce_profile_user_id_immutability()
    FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS enforce_profile_user_id_immutability_trigger
    ON public.profiles;
CREATE TRIGGER enforce_profile_user_id_immutability_trigger
BEFORE UPDATE OF user_id ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.enforce_profile_user_id_immutability();
