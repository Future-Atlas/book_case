-- Detect abrupt client IP changes per authenticated profile.

CREATE TABLE IF NOT EXISTS public.session_ip_guards (
    profile_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    last_ip INET NOT NULL,
    last_user_agent TEXT NOT NULL DEFAULT '',
    last_seen_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    ip_changed_count INTEGER NOT NULL DEFAULT 0,
    last_ip_changed_at TIMESTAMP WITH TIME ZONE
);

ALTER TABLE public.session_ip_guards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own session guard" ON public.session_ip_guards;
CREATE POLICY "Users can read own session guard"
ON public.session_ip_guards
FOR SELECT
TO authenticated
USING (auth.uid() = profile_id);

CREATE OR REPLACE FUNCTION public.check_session_ip_change(
    p_ip INET,
    p_user_agent TEXT DEFAULT ''
)
RETURNS TABLE (
    ip_changed BOOLEAN,
    previous_ip TEXT,
    current_ip TEXT,
    changed_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_profile_id UUID := auth.uid();
    v_existing public.session_ip_guards%ROWTYPE;
    v_now TIMESTAMP WITH TIME ZONE := timezone('utc'::text, now());
    v_user_agent TEXT := left(coalesce(p_user_agent, ''), 500);
BEGIN
    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
    END IF;

    IF p_ip IS NULL THEN
        RAISE EXCEPTION 'ip_required' USING ERRCODE = '22023';
    END IF;

    SELECT *
      INTO v_existing
      FROM public.session_ip_guards
     WHERE profile_id = v_profile_id
     FOR UPDATE;

    IF NOT FOUND THEN
        INSERT INTO public.session_ip_guards (
            profile_id,
            last_ip,
            last_user_agent,
            last_seen_at,
            ip_changed_count,
            last_ip_changed_at
        ) VALUES (
            v_profile_id,
            p_ip,
            v_user_agent,
            v_now,
            0,
            NULL
        );

        RETURN QUERY SELECT false, NULL::TEXT, host(p_ip), NULL::TIMESTAMP WITH TIME ZONE;
        RETURN;
    END IF;

    IF v_existing.last_ip IS DISTINCT FROM p_ip THEN
        UPDATE public.session_ip_guards
           SET last_ip = p_ip,
               last_user_agent = v_user_agent,
               last_seen_at = v_now,
               ip_changed_count = v_existing.ip_changed_count + 1,
               last_ip_changed_at = v_now
         WHERE profile_id = v_profile_id;

        RETURN QUERY SELECT true, host(v_existing.last_ip), host(p_ip), v_now;
        RETURN;
    END IF;

    UPDATE public.session_ip_guards
       SET last_user_agent = v_user_agent,
           last_seen_at = v_now
     WHERE profile_id = v_profile_id;

    RETURN QUERY SELECT false, host(v_existing.last_ip), host(p_ip), NULL::TIMESTAMP WITH TIME ZONE;
END;
$$;

REVOKE ALL ON FUNCTION public.check_session_ip_change(INET, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_session_ip_change(INET, TEXT) TO authenticated;
