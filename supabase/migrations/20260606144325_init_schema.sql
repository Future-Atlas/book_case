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
-- Books table removed – book data is managed externally via API.

-- Create posts table (user reviews)
CREATE TABLE IF NOT EXISTS public.posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    book_id TEXT NOT NULL,
    rating DOUBLE PRECISION NOT NULL CHECK (rating >= 1.0 AND rating <= 5.0),
    comment TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

-- Create favorites table (many-to-many relationship)
CREATE TABLE IF NOT EXISTS public.favorites (
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    book_id TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (profile_id, book_id)
);

ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

-- Create collections table (many-to-many relationship tracking read/reading books)
CREATE TABLE IF NOT EXISTS public.collections (
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    book_id TEXT NOT NULL,
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

-- Policy for books removed (no books table).

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
-- Seed books removed (books are fetched from external APIs).

-- Seed User Posts / Reviews
-- Seed posts removed (book references no longer valid).

-- Seed Collections
-- Seed collections removed (book references no longer valid).

-- Seed Favorites
-- Seed favorites removed (book references no longer valid).

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

-- Trigger for book rating avg removed (books table no longer exists).
