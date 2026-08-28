-- Allow users to report an individual reply without treating the whole post
-- as the moderation target.

ALTER TABLE public.moderation_reports
    ADD COLUMN IF NOT EXISTS reply_id BIGINT
        REFERENCES public.post_replies(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS reply_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb;

DROP INDEX IF EXISTS public.moderation_reports_open_unique;
CREATE UNIQUE INDEX IF NOT EXISTS moderation_reports_open_post_unique
    ON public.moderation_reports (reporter_id, post_id)
    WHERE status = 'open'
      AND post_id IS NOT NULL
      AND reply_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS moderation_reports_open_reply_unique
    ON public.moderation_reports (reporter_id, reply_id)
    WHERE status = 'open' AND reply_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS moderation_reports_reply_idx
    ON public.moderation_reports (reply_id, created_at DESC)
    WHERE reply_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.submit_reply_report(
    target_reply BIGINT,
    report_category TEXT,
    report_details TEXT DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    reporter UUID := auth.uid();
    target_reply_row public.post_replies%ROWTYPE;
    target_post_row public.posts%ROWTYPE;
    existing_id BIGINT;
    created_id BIGINT;
BEGIN
    IF reporter IS NULL OR NOT public.is_profile_active(reporter) THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Account is not active';
    END IF;

    IF report_category NOT IN (
        'spam', 'harassment', 'bullying', 'offensive', 'other'
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Invalid report category';
    END IF;

    IF report_details IS NOT NULL AND char_length(report_details) > 1000 THEN
        RAISE EXCEPTION USING
            ERRCODE = '22001',
            MESSAGE = 'Report details are too long';
    END IF;

    SELECT *
    INTO target_reply_row
    FROM public.post_replies
    WHERE id = target_reply;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Reply not found';
    END IF;

    IF target_reply_row.profile_id = reporter THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Cannot report your own reply';
    END IF;

    SELECT *
    INTO target_post_row
    FROM public.posts
    WHERE id = target_reply_row.post_id;

    IF NOT FOUND
       OR NOT public.can_view_profile_content(target_post_row.profile_id) THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Target reply is not available';
    END IF;

    SELECT id
    INTO existing_id
    FROM public.moderation_reports
    WHERE reporter_id = reporter
      AND reply_id = target_reply
      AND status = 'open';

    IF existing_id IS NOT NULL THEN
        RETURN existing_id;
    END IF;

    INSERT INTO public.moderation_reports (
        reporter_id,
        reported_profile_id,
        post_id,
        reply_id,
        category,
        details,
        post_snapshot,
        reply_snapshot
    ) VALUES (
        reporter,
        target_reply_row.profile_id,
        target_reply_row.post_id,
        target_reply_row.id,
        report_category,
        NULLIF(btrim(report_details), ''),
        jsonb_build_object(
            'post_id', target_post_row.id,
            'profile_id', target_post_row.profile_id,
            'book_id', target_post_row.book_id,
            'rating', target_post_row.rating,
            'review', target_post_row.comment,
            'created_at', target_post_row.created_at
        ),
        jsonb_build_object(
            'reply_id', target_reply_row.id,
            'profile_id', target_reply_row.profile_id,
            'parent_reply_id', target_reply_row.parent_reply_id,
            'message', target_reply_row.message,
            'created_at', target_reply_row.created_at
        )
    )
    RETURNING id INTO created_id;

    RETURN created_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_delete_reported_reply(
    target_report BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    target_reply BIGINT;
BEGIN
    IF NOT public.is_current_user_admin() THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Administrator access required';
    END IF;

    SELECT reply_id
    INTO target_reply
    FROM public.moderation_reports
    WHERE id = target_report;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Report not found';
    END IF;

    IF target_reply IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Report does not target a reply';
    END IF;

    WITH RECURSIVE reply_tree AS (
        SELECT id
        FROM public.post_replies
        WHERE id = target_reply
        UNION ALL
        SELECT child.id
        FROM public.post_replies AS child
        JOIN reply_tree AS parent ON child.parent_reply_id = parent.id
    )
    UPDATE public.moderation_reports
    SET status = 'resolved',
        resolution = 'reply_deleted',
        resolved_by = auth.uid(),
        resolved_at = timezone('utc'::text, now())
    WHERE status = 'open'
      AND (
          id = target_report
          OR reply_id IN (SELECT id FROM reply_tree)
      );

    DELETE FROM public.post_replies WHERE id = target_reply;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_reply_report(BIGINT, TEXT, TEXT)
    FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_reply_report(BIGINT, TEXT, TEXT)
    TO authenticated;

REVOKE ALL ON FUNCTION public.admin_delete_reported_reply(BIGINT)
    FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_delete_reported_reply(BIGINT)
    TO authenticated;

COMMENT ON COLUMN public.moderation_reports.reply_id IS
    'Reply targeted by the report. Null for reports targeting an entire post.';
COMMENT ON COLUMN public.moderation_reports.reply_snapshot IS
    'Immutable moderation snapshot of the reported reply.';
