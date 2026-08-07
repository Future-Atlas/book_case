-- A completed book is represented by at least one post. Keep the bookshelf
-- and read count synchronized for both user and administrator deletions.

DROP POLICY IF EXISTS "Users can delete their own posts" ON public.posts;
CREATE POLICY "Users can delete their own posts"
    ON public.posts FOR DELETE TO authenticated
    USING (
        auth.uid() = profile_id
        AND public.is_profile_active(auth.uid())
    );

CREATE INDEX IF NOT EXISTS posts_profile_created_at_idx
    ON public.posts (profile_id, created_at DESC);
CREATE INDEX IF NOT EXISTS posts_profile_book_created_at_idx
    ON public.posts (profile_id, book_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.sync_bookshelf_after_post_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    affected_profile_id UUID;
    affected_book_id TEXT;
    latest_post_at TIMESTAMP WITH TIME ZONE;
BEGIN
    affected_profile_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.profile_id ELSE NEW.profile_id END;
    affected_book_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.book_id ELSE NEW.book_id END;

    SELECT max(created_at)
    INTO latest_post_at
    FROM public.posts
    WHERE profile_id = affected_profile_id
      AND book_id = affected_book_id;

    IF latest_post_at IS NULL THEN
        DELETE FROM public.collections
        WHERE profile_id = affected_profile_id
          AND book_id = affected_book_id;
    ELSE
        INSERT INTO public.collections (profile_id, book_id, status, created_at)
        VALUES (affected_profile_id, affected_book_id, 'read', latest_post_at)
        ON CONFLICT (profile_id, book_id) DO UPDATE
        SET status = 'read',
            created_at = EXCLUDED.created_at;
    END IF;

    UPDATE public.profiles
    SET read_count = (
        SELECT count(DISTINCT book_id)::INTEGER
        FROM public.posts
        WHERE profile_id = affected_profile_id
    )
    WHERE id = affected_profile_id;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_bookshelf_after_post_change_trigger
    ON public.posts;
CREATE TRIGGER sync_bookshelf_after_post_change_trigger
    AFTER INSERT OR DELETE ON public.posts
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_bookshelf_after_post_change();

-- Align existing bookshelf rows and counts with the posts already stored.
INSERT INTO public.collections (profile_id, book_id, status, created_at)
SELECT profile_id, book_id, 'read', max(created_at)
FROM public.posts
GROUP BY profile_id, book_id
ON CONFLICT (profile_id, book_id) DO UPDATE
SET status = 'read',
    created_at = EXCLUDED.created_at;

DELETE FROM public.collections AS collection
WHERE collection.status = 'read'
  AND NOT EXISTS (
      SELECT 1
      FROM public.posts AS post
      WHERE post.profile_id = collection.profile_id
        AND post.book_id = collection.book_id
  );

UPDATE public.profiles AS profile
SET read_count = (
    SELECT count(DISTINCT post.book_id)::INTEGER
    FROM public.posts AS post
    WHERE post.profile_id = profile.id
);

REVOKE ALL ON FUNCTION public.sync_bookshelf_after_post_change()
    FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION public.sync_bookshelf_after_post_change() IS
    'Keeps completed-book shelves and read counts synchronized with posts.';
