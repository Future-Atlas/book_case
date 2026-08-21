-- Public profile accent color used for headers and post borders.
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS page_color TEXT NOT NULL DEFAULT 'yellow';

ALTER TABLE public.profiles
DROP CONSTRAINT IF EXISTS profiles_page_color_check;

ALTER TABLE public.profiles
ADD CONSTRAINT profiles_page_color_check CHECK (
    page_color IN (
        'red',
        'magenta',
        'blue',
        'yellow',
        'green',
        'purple',
        'gray',
        'orange',
        'pink',
        'light_blue',
        'emerald',
        'red_purple',
        'yellow_green',
        'brown'
    )
);

CREATE OR REPLACE FUNCTION public.update_profile_page_color(
    p_page_color TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    IF p_page_color IS NULL OR p_page_color NOT IN (
        'red',
        'magenta',
        'blue',
        'yellow',
        'green',
        'purple',
        'gray',
        'orange',
        'pink',
        'light_blue',
        'emerald',
        'red_purple',
        'yellow_green',
        'brown'
    ) THEN
        RAISE EXCEPTION 'Invalid page color' USING ERRCODE = '23514';
    END IF;

    UPDATE public.profiles
    SET page_color = p_page_color
    WHERE id = auth.uid();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found' USING ERRCODE = 'P0002';
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.update_profile_page_color(TEXT)
    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_profile_page_color(TEXT)
    TO authenticated;
