-- Add a persistent want-to-read shelf and post-level want-to-read engagement.

CREATE TABLE IF NOT EXISTS public.want_to_read_books (
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    book_id TEXT NOT NULL,
    book_title TEXT NOT NULL DEFAULT '',
    book_author TEXT NOT NULL DEFAULT '',
    book_cover_url TEXT NOT NULL DEFAULT '',
    saved_directly BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (profile_id, book_id),
    CHECK (char_length(btrim(book_id)) > 0)
);

CREATE TABLE IF NOT EXISTS public.post_want_to_reads (
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (post_id, profile_id)
);

CREATE INDEX IF NOT EXISTS want_to_read_books_profile_created_idx
    ON public.want_to_read_books (profile_id, created_at DESC);
CREATE INDEX IF NOT EXISTS post_want_to_reads_post_created_idx
    ON public.post_want_to_reads (post_id, created_at DESC);
CREATE INDEX IF NOT EXISTS post_want_to_reads_profile_idx
    ON public.post_want_to_reads (profile_id);

ALTER TABLE public.want_to_read_books ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_want_to_reads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Visible want-to-read shelves can be read"
    ON public.want_to_read_books;
CREATE POLICY "Visible want-to-read shelves can be read"
    ON public.want_to_read_books FOR SELECT
    USING (public.can_view_profile_content(profile_id));

DROP POLICY IF EXISTS "Visible post want-to-read engagements can be read"
    ON public.post_want_to_reads;
CREATE POLICY "Visible post want-to-read engagements can be read"
    ON public.post_want_to_reads FOR SELECT
    USING (
        EXISTS (
            SELECT 1
            FROM public.posts
            WHERE posts.id = post_want_to_reads.post_id
              AND public.can_view_profile_content(posts.profile_id)
        )
    );

-- Changes go through the RPC below so direct saves and post attribution stay
-- consistent. No client-side INSERT/UPDATE/DELETE grants are needed.
GRANT SELECT ON public.want_to_read_books TO anon, authenticated;
GRANT SELECT ON public.post_want_to_reads TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.toggle_want_to_read(
    target_book_id TEXT,
    target_book_title TEXT DEFAULT '',
    target_book_author TEXT DEFAULT '',
    target_book_cover_url TEXT DEFAULT '',
    source_post_id UUID DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    actor UUID := auth.uid();
    target_post public.posts%ROWTYPE;
    existing_direct BOOLEAN;
    has_other_post_source BOOLEAN;
BEGIN
    IF actor IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Authentication required';
    END IF;
    IF NOT public.is_profile_active(actor) THEN
        RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Account is not active';
    END IF;
    target_book_id := btrim(COALESCE(target_book_id, ''));
    IF target_book_id = '' THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Book ID is required';
    END IF;

    IF source_post_id IS NULL THEN
        SELECT saved_directly
        INTO existing_direct
        FROM public.want_to_read_books
        WHERE profile_id = actor AND book_id = target_book_id;

        IF FOUND THEN
            DELETE FROM public.post_want_to_reads AS engagement
            USING public.posts AS post
            WHERE engagement.post_id = post.id
              AND engagement.profile_id = actor
              AND post.book_id = target_book_id;
            DELETE FROM public.want_to_read_books
            WHERE profile_id = actor AND book_id = target_book_id;
            RETURN 'removed';
        END IF;

        INSERT INTO public.want_to_read_books (
            profile_id, book_id, book_title, book_author, book_cover_url,
            saved_directly, updated_at
        ) VALUES (
            actor,
            target_book_id,
            left(COALESCE(target_book_title, ''), 500),
            left(COALESCE(target_book_author, ''), 500),
            left(COALESCE(target_book_cover_url, ''), 2000),
            TRUE,
            timezone('utc'::text, now())
        )
        ON CONFLICT (profile_id, book_id) DO UPDATE
        SET book_title = CASE
                WHEN EXCLUDED.book_title = '' THEN want_to_read_books.book_title
                ELSE EXCLUDED.book_title
            END,
            book_author = CASE
                WHEN EXCLUDED.book_author = '' THEN want_to_read_books.book_author
                ELSE EXCLUDED.book_author
            END,
            book_cover_url = CASE
                WHEN EXCLUDED.book_cover_url = '' THEN want_to_read_books.book_cover_url
                ELSE EXCLUDED.book_cover_url
            END,
            saved_directly = TRUE,
            updated_at = timezone('utc'::text, now());
        RETURN 'added';
    END IF;

    SELECT * INTO target_post FROM public.posts WHERE id = source_post_id;
    IF NOT FOUND
       OR target_post.book_id <> target_book_id
       OR NOT public.can_view_profile_content(target_post.profile_id) THEN
        RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Post is not available';
    END IF;
    IF target_post.profile_id = actor THEN
        RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Cannot react to your own post';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.post_want_to_reads
        WHERE post_id = source_post_id AND profile_id = actor
    ) THEN
        DELETE FROM public.post_want_to_reads
        WHERE post_id = source_post_id AND profile_id = actor;

        SELECT COALESCE(saved_directly, FALSE)
        INTO existing_direct
        FROM public.want_to_read_books
        WHERE profile_id = actor AND book_id = target_book_id;

        SELECT EXISTS (
            SELECT 1
            FROM public.post_want_to_reads AS engagement
            JOIN public.posts AS post ON post.id = engagement.post_id
            WHERE engagement.profile_id = actor
              AND post.book_id = target_book_id
        ) INTO has_other_post_source;

        IF NOT COALESCE(existing_direct, FALSE) AND NOT has_other_post_source THEN
            DELETE FROM public.want_to_read_books
            WHERE profile_id = actor AND book_id = target_book_id;
        END IF;
        RETURN 'removed';
    END IF;

    INSERT INTO public.post_want_to_reads (post_id, profile_id)
    VALUES (source_post_id, actor);

    INSERT INTO public.want_to_read_books (
        profile_id, book_id, book_title, book_author, book_cover_url,
        saved_directly, updated_at
    ) VALUES (
        actor,
        target_book_id,
        left(COALESCE(target_book_title, target_post.book_title, ''), 500),
        left(COALESCE(target_book_author, target_post.book_author, ''), 500),
        left(COALESCE(target_book_cover_url, ''), 2000),
        FALSE,
        timezone('utc'::text, now())
    )
    ON CONFLICT (profile_id, book_id) DO UPDATE
    SET book_title = CASE
            WHEN EXCLUDED.book_title = '' THEN want_to_read_books.book_title
            ELSE EXCLUDED.book_title
        END,
        book_author = CASE
            WHEN EXCLUDED.book_author = '' THEN want_to_read_books.book_author
            ELSE EXCLUDED.book_author
        END,
        book_cover_url = CASE
            WHEN EXCLUDED.book_cover_url = '' THEN want_to_read_books.book_cover_url
            ELSE EXCLUDED.book_cover_url
        END,
        updated_at = timezone('utc'::text, now());
    RETURN 'added';
END;
$$;

REVOKE ALL ON FUNCTION public.toggle_want_to_read(TEXT, TEXT, TEXT, TEXT, UUID)
    FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.toggle_want_to_read(TEXT, TEXT, TEXT, TEXT, UUID)
    TO authenticated;

ALTER TABLE public.notifications
    DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications
    ADD CONSTRAINT notifications_type_check
    CHECK (
        type IN (
            'reaction', 'want_to_read', 'follow', 'follow_request', 'reply',
            'new_post'
        )
    );

ALTER TABLE public.notifications
    DROP CONSTRAINT IF EXISTS notifications_check1;
ALTER TABLE public.notifications
    ADD CONSTRAINT notifications_check1
    CHECK (
        (
            type IN ('reaction', 'want_to_read', 'new_post')
            AND post_id IS NOT NULL
            AND reply_id IS NULL
        )
        OR (
            type = 'reply'
            AND post_id IS NOT NULL
            AND reply_id IS NOT NULL
        )
        OR (
            type IN ('follow', 'follow_request')
            AND post_id IS NULL
            AND reply_id IS NULL
        )
    );

CREATE OR REPLACE FUNCTION public.create_want_to_read_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    post_owner UUID;
BEGIN
    SELECT profile_id INTO post_owner FROM public.posts WHERE id = NEW.post_id;
    IF post_owner IS NOT NULL AND post_owner <> NEW.profile_id THEN
        INSERT INTO public.notifications (recipient_id, actor_id, type, post_id)
        VALUES (post_owner, NEW.profile_id, 'want_to_read', NEW.post_id);
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS post_want_to_reads_create_notification
    ON public.post_want_to_reads;
CREATE TRIGGER post_want_to_reads_create_notification
AFTER INSERT ON public.post_want_to_reads
FOR EACH ROW EXECUTE FUNCTION public.create_want_to_read_notification();

REVOKE ALL ON FUNCTION public.create_want_to_read_notification() FROM PUBLIC;

COMMENT ON TABLE public.want_to_read_books IS
    'Books saved to a profile want-to-read shelf.';
COMMENT ON TABLE public.post_want_to_reads IS
    'Post-attributed want-to-read engagement used for counts and notifications.';
