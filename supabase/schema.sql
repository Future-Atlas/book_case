/* Updated schema for API‑only book data */
-- Create profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    avatar_url TEXT,
    bio TEXT,
    followers_count INTEGER DEFAULT 0,
    following_count INTEGER DEFAULT 0,
    read_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- NOTE: books table removed; external API provides book data.

-- Posts now reference external book IDs (ISBN or other) as plain TEXT
CREATE TABLE IF NOT EXISTS public.posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    book_id TEXT NOT NULL,
    rating DOUBLE PRECISION NOT NULL CHECK (rating >= 1.0 AND rating <= 5.0),
    comment TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

-- Favorites reference external book IDs as TEXT
CREATE TABLE IF NOT EXISTS public.favorites (
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    book_id TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (profile_id, book_id)
);

ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

-- Collections track reading status for external book IDs as TEXT
CREATE TABLE IF NOT EXISTS public.collections (
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    book_id TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('to_read', 'reading', 'read')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (profile_id, book_id)
);

ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;

-- RLS Policies (same as before)
CREATE POLICY "Allow public read access for profiles" ON public.profiles
    FOR SELECT USING (true);

CREATE POLICY "Allow users to update their own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Allow users to insert their own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Allow public read access for posts" ON public.posts
    FOR SELECT USING (true);

CREATE POLICY "Allow authenticated users to insert posts" ON public.posts
    FOR INSERT WITH CHECK (auth.uid() = profile_id);

CREATE POLICY "Allow public read access for favorites" ON public.favorites
    FOR SELECT USING (true);

CREATE POLICY "Allow authenticated users to insert/delete favorites" ON public.favorites
    FOR ALL USING (auth.uid() = profile_id);

CREATE POLICY "Allow public read access for collections" ON public.collections
    FOR SELECT USING (true);

CREATE POLICY "Allow authenticated users to insert/delete collections" ON public.collections
    FOR ALL USING (auth.uid() = profile_id);

-- Seed data now only includes profiles (books are fetched from external APIs)
INSERT INTO public.profiles (id, username, avatar_url, bio, followers_count, following_count, read_count)
VALUES
    ('d3b07384-d113-4ec5-a587-f3e098a58f4a', 'ryu_booklover', 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80', '本を読むのが大好きなソフトウェアエンジニア。最近はSF小説とミステリーを多く読んでいます。', 128, 94, 42)
ON CONFLICT (id) DO NOTHING;

-- Seed user posts (book_id now holds an external identifier e.g., ISBN)
INSERT INTO public.posts (id, profile_id, book_id, rating, comment, created_at)
VALUES
    ('e1111111-1111-1111-1111-111111111111', 'd3b07384-d113-4ec5-a587-f3e098a58f4a', '9780307465351', 5.0, 'SF小説の最高傑作！最初から最後まで興奮が収まらなかった。キャラクターの掛け合いも最高。', now() - INTERVAL '2 days'),
    ('e2222222-2222-2222-2222-222222222222', 'd3b07384-d113-4ec5-a587-f3e098a58f4a', '9784087250000', 4.5, '読むたびに新しい発見がある素晴らしい本。言葉の響きが美しく、切ないストーリーに胸が締め付けられます。', now() - INTERVAL '5 days'),
    ('e3333333-3333-3333-3333-333333333333', 'd3b07384-d113-4ec5-a587-f3e098a48f4a', '9784101029000', 4.0, '孤独と葛藤がストレートに伝わってくる。時代を超えて愛される理由がわかります。', now() - INTERVAL '10 days')
ON CONFLICT (id) DO NOTHING;

-- Seed collections and favorites (using external IDs)
INSERT INTO public.collections (profile_id, book_id, status)
VALUES
    ('d3b07384-d113-4ec5-a587-f3e098a58f4a', '9780307465351', 'read'),
    ('d3b07384-d113-4ec5-a587-f3e098a58f4a', '9784087250000', 'read'),
    ('d3b07384-d113-4ec5-a587-f3e098a58f4a', '9784101029000', 'read')
ON CONFLICT (profile_id, book_id) DO NOTHING;

INSERT INTO public.favorites (profile_id, book_id)
VALUES
    ('d3b07384-d113-4ec5-a587-f3e098a58f4a', '9780307465351'),
    ('d3b07384-d113-4ec5-a587-f3e098a58f4a', '9784087250000'),
    ('d3b07384-d113-4ec5-a587-f3e098a58f4a', '9784101029000')
ON CONFLICT (profile_id, book_id) DO NOTHING;

-- Helper function to increment read count (RPC callable)
CREATE OR REPLACE FUNCTION public.increment_read_count(user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.profiles
    SET read_count = read_count + 1
    WHERE id = user_id;
END;
$$;

-- Trigger function to automatically update book rating_avg when reviews change (now calculates on external IDs)
CREATE OR REPLACE FUNCTION public.update_book_rating_avg()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- No books table; rating aggregation can be done in app layer if needed.
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_post_modified
    AFTER INSERT OR UPDATE OR DELETE ON public.posts
    FOR EACH ROW EXECUTE FUNCTION public.update_book_rating_avg();
