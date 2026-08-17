-- Prevent future duplicate reviews without deleting or rewriting existing data.
CREATE OR REPLACE FUNCTION public.prevent_duplicate_book_post()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    PERFORM pg_advisory_xact_lock(
        hashtextextended(NEW.profile_id::text || ':' || NEW.book_id, 0)
    );

    IF EXISTS (
        SELECT 1
        FROM public.posts
        WHERE profile_id = NEW.profile_id
          AND book_id = NEW.book_id
    ) THEN
        RAISE EXCEPTION 'duplicate_book_post'
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prevent_duplicate_book_post_before_insert
    ON public.posts;
CREATE TRIGGER prevent_duplicate_book_post_before_insert
BEFORE INSERT ON public.posts
FOR EACH ROW
EXECUTE FUNCTION public.prevent_duplicate_book_post();

-- Favorites may contain only books for which that profile has a post.
CREATE OR REPLACE FUNCTION public.enforce_favorites_limit()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
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

-- Removing a post also removes its favorite, keeping My Bookshelf and
-- Favorites consistent with the completed-book source of truth.
CREATE OR REPLACE FUNCTION public.remove_favorite_after_post_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM public.posts
        WHERE profile_id = OLD.profile_id
          AND book_id = OLD.book_id
    ) THEN
        DELETE FROM public.favorites
        WHERE profile_id = OLD.profile_id
          AND book_id = OLD.book_id;
    END IF;
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS remove_favorite_after_post_delete_trigger
    ON public.posts;
CREATE TRIGGER remove_favorite_after_post_delete_trigger
AFTER DELETE ON public.posts
FOR EACH ROW
EXECUTE FUNCTION public.remove_favorite_after_post_delete();

REVOKE ALL ON FUNCTION public.prevent_duplicate_book_post()
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.remove_favorite_after_post_delete()
    FROM PUBLIC, anon, authenticated;
