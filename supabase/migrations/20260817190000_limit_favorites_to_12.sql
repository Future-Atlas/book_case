-- Keep the profile favorites grid intentionally limited to twelve books.
-- The advisory lock serializes simultaneous inserts for the same profile.
CREATE OR REPLACE FUNCTION public.enforce_favorites_limit()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext(NEW.profile_id::text)::bigint);

    IF (
        SELECT count(*)
        FROM public.favorites
        WHERE profile_id = NEW.profile_id
    ) >= 12 THEN
        RAISE EXCEPTION 'favorite_limit_reached'
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_favorites_limit_before_insert
    ON public.favorites;
CREATE TRIGGER enforce_favorites_limit_before_insert
BEFORE INSERT ON public.favorites
FOR EACH ROW
EXECUTE FUNCTION public.enforce_favorites_limit();
