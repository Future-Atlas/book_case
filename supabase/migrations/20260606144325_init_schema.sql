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

-- Enable Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Create books table
CREATE TABLE IF NOT EXISTS public.books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    cover_url TEXT,
    genre TEXT NOT NULL,
    description TEXT,
    rating_avg DOUBLE PRECISION DEFAULT 0.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.books ENABLE ROW LEVEL SECURITY;

-- Create posts table (user reviews)
CREATE TABLE IF NOT EXISTS public.posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    book_id UUID REFERENCES public.books(id) ON DELETE CASCADE NOT NULL,
    rating DOUBLE PRECISION NOT NULL CHECK (rating >= 1.0 AND rating <= 5.0),
    comment TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

-- Create favorites table (many-to-many relationship)
CREATE TABLE IF NOT EXISTS public.favorites (
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    book_id UUID REFERENCES public.books(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (profile_id, book_id)
);

ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

-- Create collections table (many-to-many relationship tracking read/reading books)
CREATE TABLE IF NOT EXISTS public.collections (
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    book_id UUID REFERENCES public.books(id) ON DELETE CASCADE NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('to_read', 'reading', 'read')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (profile_id, book_id)
);

ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;

-- Setup RLS Policies (Allow public read, authenticated write)
CREATE POLICY "Allow public read access for profiles" ON public.profiles
    FOR SELECT USING (true);

CREATE POLICY "Allow users to update their own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Allow public read access for books" ON public.books
    FOR SELECT USING (true);

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

-- Insert Seed Data (Useful for local testing and initial load)

-- Note: In a real app, user IDs correspond to auth.users IDs. For seed data, we use static UUIDs.
INSERT INTO public.profiles (id, username, avatar_url, bio, followers_count, following_count, read_count)
VALUES 
('d3b07384-d113-4ec5-a587-f3e098a58f4a', 'ryu_booklover', 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80', '本を読むのが大好きなソフトウェアエンジニア。最近はSF小説とミステリーを多く読んでいます。', 128, 94, 42)
ON CONFLICT (id) DO NOTHING;

-- Seed Books
INSERT INTO public.books (id, title, author, cover_url, genre, description, rating_avg)
VALUES
('b1111111-1111-1111-1111-111111111111', 'Project Hail Mary', 'Andy Weir', 'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?auto=format&fit=crop&w=400&q=80', '洋書', 'A lone astronaut must save the earth from an extinction-level event.', 4.8),
('b2222222-2222-2222-2222-222222222222', 'Dune', 'Frank Herbert', 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?auto=format&fit=crop&w=400&q=80', '洋書', 'Set on the desert planet Arrakis, Dune is the story of the boy Paul Atreides.', 4.5),
('b3333333-3333-3333-3333-333333333333', 'Klara and the Sun', 'Kazuo Ishiguro', 'https://images.unsplash.com/photo-1589829085413-56de8ae18c73?auto=format&fit=crop&w=400&q=80', '洋書', 'The story of Klara, an Artificial Friend with outstanding observational qualities.', 4.2),
('b4444444-4444-4444-4444-444444444444', '銀河鉄道の夜', '宮沢賢治', 'https://images.unsplash.com/photo-1512820790803-83ca734da794?auto=format&fit=crop&w=400&q=80', '人気', '貧しい少年ジョバンニが、親友カムパネルラと銀河鉄道の旅をする幻想小説。', 4.7),
('b5555555-5555-5555-5555-555555555555', '人間失格', '太宰治', 'https://images.unsplash.com/photo-1495640388908-05fa85288e61?auto=format&fit=crop&w=400&q=80', '人気', '「恥の多い生涯を送って来ました。」で始まる太宰治の自伝的小説。', 4.4),
('b6666666-6666-6666-6666-666666666666', 'ノルウェイの森', '村上春樹', 'https://images.unsplash.com/photo-1506880018603-83d5b814b5a6?auto=format&fit=crop&w=400&q=80', '人気', '主人公 of ワタナベが、直子と緑という二人の少女の間で揺れる恋と喪失の物語。', 4.6),
('b7777777-7777-7777-7777-777777777777', 'こころ', '夏目漱石', 'https://images.unsplash.com/photo-1476275466078-4007374efbbe?auto=format&fit=crop&w=400&q=80', '文学', '「先生」と私、そして先生の遺書を通じて描かれる人間のエゴイズムと倫理。', 4.5)
ON CONFLICT (id) DO NOTHING;

-- Seed User Posts / Reviews
INSERT INTO public.posts (id, profile_id, book_id, rating, comment, created_at)
VALUES
('e1111111-1111-1111-1111-111111111111', 'd3b07384-d113-4ec5-a587-f3e098a58f4a', 'b1111111-1111-1111-1111-111111111111', 5.0, 'SF小説の最高傑作！最初から最後まで興奮が収まらなかった。キャラクターの掛け合いも最高。', now() - INTERVAL '2 days'),
('e2222222-2222-2222-2222-222222222222', 'd3b07384-d113-4ec5-a587-f3e098a58f4a', 'b4444444-4444-4444-4444-444444444444', 4.5, '読むたびに新しい発見がある素晴らしい本。言葉の響きが美しく、切ないストーリーに胸が締め付けられます。', now() - INTERVAL '5 days'),
('e3333333-3333-3333-3333-333333333333', 'd3b07384-d113-4ec5-a587-f3e098a58f4a', 'b5555555-5555-5555-5555-555555555555', 4.0, '孤独と葛藤がストレートに伝わってくる。時代を超えて愛される理由がわかります。', now() - INTERVAL '10 days')
ON CONFLICT (id) DO NOTHING;

-- Seed Collections
INSERT INTO public.collections (profile_id, book_id, status)
VALUES
('d3b07384-d113-4ec5-a587-f3e098a58f4a', 'b1111111-1111-1111-1111-111111111111', 'read'),
('d3b07384-d113-4ec5-a587-f3e098a58f4a', 'b2222222-2222-2222-2222-222222222222', 'read'),
('d3b07384-d113-4ec5-a587-f3e098a58f4a', 'b3333333-3333-3333-3333-333333333333', 'read'),
('d3b07384-d113-4ec5-a587-f3e098a58f4a', 'b4444444-4444-4444-4444-444444444444', 'read'),
('d3b07384-d113-4ec5-a587-f3e098a58f4a', 'b5555555-5555-5555-5555-555555555555', 'read'),
('d3b07384-d113-4ec5-a587-f3e098a58f4a', 'b6666666-6666-6666-6666-666666666666', 'read')
ON CONFLICT (profile_id, book_id) DO NOTHING;

-- Seed Favorites
INSERT INTO public.favorites (profile_id, book_id)
VALUES
('d3b07384-d113-4ec5-a587-f3e098a58f4a', 'b1111111-1111-1111-1111-111111111111'),
('d3b07384-d113-4ec5-a587-f3e098a58f4a', 'b4444444-4444-4444-4444-444444444444'),
('d3b07384-d113-4ec5-a587-f3e098a58f4a', 'b6666666-6666-6666-6666-666666666666')
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

-- Trigger function to automatically update book rating_avg when reviews change
CREATE OR REPLACE FUNCTION public.update_book_rating_avg()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.books
    SET rating_avg = (
        SELECT COALESCE(AVG(rating), 0.0)
        FROM public.posts
        WHERE book_id = COALESCE(NEW.book_id, OLD.book_id)
    )
    WHERE id = COALESCE(NEW.book_id, OLD.book_id);
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_post_modified
    AFTER INSERT OR UPDATE OR DELETE ON public.posts
    FOR EACH ROW EXECUTE FUNCTION public.update_book_rating_avg();
