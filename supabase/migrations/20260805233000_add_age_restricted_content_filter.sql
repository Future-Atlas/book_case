-- Age-restricted book metadata, configurable filter terms, and server-side
-- enforcement for viewers under 18.

ALTER TABLE public.posts
    ADD COLUMN IF NOT EXISTS book_title TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS book_author TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS book_publisher TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS book_description TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS is_age_restricted BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS posts_age_restricted_idx
    ON public.posts (is_age_restricted)
    WHERE is_age_restricted = true;

CREATE TABLE IF NOT EXISTS public.adult_content_terms (
    term TEXT PRIMARY KEY CHECK (char_length(btrim(term)) BETWEEN 2 AND 100),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE
        NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE
        NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.adult_content_terms ENABLE ROW LEVEL SECURITY;

INSERT INTO public.adult_content_terms (term) VALUES
    ('成人向け'),
    ('成人指定'),
    ('成人雑誌'),
    ('成年向け'),
    ('成年コミック'),
    ('成人コミック'),
    ('18禁'),
    ('r18'),
    ('r-18'),
    ('アダルト'),
    ('エロ本'),
    ('ポルノ'),
    ('hentai'),
    ('pornography'),
    ('pornographic'),
    ('adult magazine'),
    ('adults only'),
    ('sexually explicit')
ON CONFLICT (term) DO NOTHING;

CREATE OR REPLACE FUNCTION public.normalize_content_filter_text(source TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
SET search_path = public
AS $$
    SELECT lower(
        regexp_replace(
            coalesce(source, ''),
            '[[:space:]　_\-‐‑‒–—―・･.／/]+',
            '',
            'g'
        )
    );
$$;

CREATE OR REPLACE FUNCTION public.matches_adult_content_terms(
    book_title TEXT,
    book_author TEXT,
    book_publisher TEXT,
    book_description TEXT,
    post_comment TEXT DEFAULT ''
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.adult_content_terms AS filter_term
        WHERE filter_term.is_active = true
          AND position(
              public.normalize_content_filter_text(filter_term.term)
              IN public.normalize_content_filter_text(
                  concat_ws(
                      ' ',
                      book_title,
                      book_author,
                      book_publisher,
                      book_description,
                      post_comment
                  )
              )
          ) > 0
    );
$$;

CREATE OR REPLACE FUNCTION public.classify_post_age_restriction()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    NEW.is_age_restricted :=
        COALESCE(NEW.is_age_restricted, false)
        OR public.matches_adult_content_terms(
            NEW.book_title,
            NEW.book_author,
            NEW.book_publisher,
            NEW.book_description,
            NEW.comment
        );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS classify_post_age_restriction_trigger
    ON public.posts;
CREATE TRIGGER classify_post_age_restriction_trigger
    BEFORE INSERT OR UPDATE OF
        book_title,
        book_author,
        book_publisher,
        book_description,
        comment
    ON public.posts
    FOR EACH ROW
    EXECUTE FUNCTION public.classify_post_age_restriction();

UPDATE public.posts
SET is_age_restricted = public.matches_adult_content_terms(
    book_title,
    book_author,
    book_publisher,
    book_description,
    comment
);

CREATE OR REPLACE FUNCTION public.current_user_is_adult()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.account_details
        WHERE profile_id = auth.uid()
          AND birth_date <= (CURRENT_DATE - INTERVAL '18 years')::date
    );
$$;

CREATE OR REPLACE FUNCTION public.current_user_can_view_age_restricted()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT public.current_user_is_adult()
        OR EXISTS (
            SELECT 1
            FROM public.app_admins
            WHERE profile_id = auth.uid()
        );
$$;

DROP POLICY IF EXISTS "Administrators can manage adult content terms"
    ON public.adult_content_terms;
CREATE POLICY "Administrators can manage adult content terms"
    ON public.adult_content_terms
    FOR ALL TO authenticated
    USING (public.is_current_user_admin())
    WITH CHECK (public.is_current_user_admin());

DROP POLICY IF EXISTS "Allow visible profile posts to be read" ON public.posts;
CREATE POLICY "Allow visible profile posts to be read"
    ON public.posts FOR SELECT
    USING (
        public.can_view_profile_content(profile_id)
        AND (
            is_age_restricted = false
            OR public.current_user_can_view_age_restricted()
        )
    );

DROP POLICY IF EXISTS "Allow authenticated users to insert posts" ON public.posts;
CREATE POLICY "Allow authenticated users to insert posts"
    ON public.posts FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() = profile_id
        AND public.is_profile_active(auth.uid())
        AND char_length(btrim(book_title)) > 0
        AND (
            is_age_restricted = false
            OR public.current_user_is_adult()
        )
    );

REVOKE ALL ON FUNCTION public.normalize_content_filter_text(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.matches_adult_content_terms(TEXT, TEXT, TEXT, TEXT, TEXT)
    FROM PUBLIC;
REVOKE ALL ON FUNCTION public.current_user_is_adult() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.current_user_can_view_age_restricted() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.current_user_is_adult()
    TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_can_view_age_restricted()
    TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.adult_content_terms
    TO authenticated;

COMMENT ON TABLE public.adult_content_terms IS
    'Server-side terms used to identify age-restricted books and posts. Only administrators can access this table.';
COMMENT ON COLUMN public.posts.is_age_restricted IS
    'Set automatically when book metadata or the review matches an active adult-content term.';
