ALTER TABLE public.posts
    ADD COLUMN IF NOT EXISTS edited_at TIMESTAMP WITH TIME ZONE;

DROP POLICY IF EXISTS "Users can update their own posts" ON public.posts;
CREATE POLICY "Users can update their own posts"
ON public.posts
FOR UPDATE
TO authenticated
USING (auth.uid() = profile_id)
WITH CHECK (auth.uid() = profile_id);

-- A review may be edited, but it must always remain attached to the book and
-- author account it was originally posted for.
CREATE OR REPLACE FUNCTION public.protect_post_identity_on_update()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF NEW.profile_id IS DISTINCT FROM OLD.profile_id
       OR NEW.book_id IS DISTINCT FROM OLD.book_id THEN
        RAISE EXCEPTION 'post_identity_cannot_be_changed'
            USING ERRCODE = 'P0001';
    END IF;

    NEW.created_at := OLD.created_at;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_post_identity_before_update ON public.posts;
CREATE TRIGGER protect_post_identity_before_update
BEFORE UPDATE ON public.posts
FOR EACH ROW
EXECUTE FUNCTION public.protect_post_identity_on_update();

COMMENT ON COLUMN public.posts.edited_at IS
    'Set when the post author edits the review, rating, or spoiler setting.';
