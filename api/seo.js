// Vercel serverless function to handle crawler requests for SEO
// Fetches data from Supabase and renders a static, semantic HTML page.

const SUPABASE_URL = process.env.SUPABASE_URL || "";
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || "";

const FALLBACK_BOOKS = [
    {
        id: "1",
        title: "Project Hail Mary",
        author: "Andy Weir",
        genre: "洋書",
        rating_avg: 4.8,
    },
    {
        id: "2",
        title: "Dune",
        author: "Frank Herbert",
        genre: "洋書",
        rating_avg: 4.5,
    },
    {
        id: "3",
        title: "銀河鉄道の夜",
        author: "宮沢賢治",
        genre: "人気",
        rating_avg: 4.7,
    },
];

const FALLBACK_POSTS = [
    {
        id: "101",
        username: "ryu_booklover",
        book_title: "Project Hail Mary",
        rating: 5,
        comment: "SF小説の最高傑作。最初から最後まで興奮が収まらなかった。",
        date: "2026-06-04",
    },
];

function escapeHtml(value) {
    return String(value ?? "")
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");
}

function supabaseHeaders() {
    return {
        apikey: SUPABASE_ANON_KEY,
        Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
    };
}

async function supabaseGet(pathAndQuery) {
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY) return null;

    const response = await fetch(`${SUPABASE_URL}/rest/v1/${pathAndQuery}`, {
        headers: supabaseHeaders(),
    });

    if (!response.ok) {
        const body = await response.text();
        throw new Error(`Supabase request failed: ${response.status} ${body}`);
    }

    return response.json();
}

module.exports = async (req, res) => {
    const { path } = req.query;
    const decodedPath = decodeURIComponent(path || "");

    // Log for debugging inside Vercel Dashboard
    console.log(`SEO Crawler requested path: ${decodedPath}`);

    // Base HTML template builder
    const renderPage = ({ title, description, content, jsonLd }) => `
    <!DOCTYPE html>
    <html lang="ja">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>${title} | BookCase</title>
      <meta name="description" content="${description}">
      <meta property="og:title" content="${title} | BookCase">
      <meta property="og:description" content="${description}">
      <meta property="og:type" content="website">
      <meta name="twitter:card" content="summary_large_image">
      <meta name="twitter:title" content="${title}">
      <meta name="twitter:description" content="${description}">
      ${jsonLd ? `<script type="application/ld+json">${JSON.stringify(jsonLd)}</script>` : ""}
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; color: #333; max-width: 800px; margin: 0 auto; padding: 20px; }
        header { border-bottom: 2px solid #ff3b30; padding-bottom: 10px; margin-bottom: 20px; }
        h1 { color: #ff3b30; margin: 0; }
        h2 { border-bottom: 1px solid #ddd; padding-bottom: 5px; margin-top: 30px; }
        .book-item { display: flex; margin-bottom: 15px; border: 1px solid #eee; border-radius: 8px; padding: 10px; }
        .book-cover { width: 60px; height: 90px; object-fit: cover; margin-right: 15px; border-radius: 4px; }
        .book-details { flex: 1; }
        .book-title { font-weight: bold; font-size: 1.1em; margin: 0; }
        .book-author { color: #666; font-size: 0.9em; margin: 5px 0; }
        .post-card { border: 1px solid #eee; border-radius: 8px; padding: 15px; margin-bottom: 15px; background: #fafafa; }
        .post-header { display: flex; justify-content: space-between; margin-bottom: 10px; }
        .post-rating { color: #ffcc00; font-weight: bold; }
        .post-comment { font-style: italic; color: #555; }
        footer { margin-top: 50px; text-align: center; font-size: 0.8em; color: #999; border-top: 1px solid #eee; padding-top: 20px; }
      </style>
    </head>
    <body>
      <header>
        <h1>BookCase</h1>
        <p>iOS, Android, and Web Book Organizer</p>
      </header>
      <main>
        ${content}
      </main>
      <footer>
        <p>© 2026 BookCase. All rights reserved.</p>
      </footer>
    </body>
    </html>
  `;

    // If path contains "/user" or starts with "user", render user profile page
    if (decodedPath.includes("user") || decodedPath.includes("profile")) {
        let username = "ryu_booklover";
        let bio =
            "本を読むのが大好きなソフトウェアエンジニア。最近はSF小説とミステリーを多く読んでいます。";
        let stats = { read: 42, followers: 128, following: 94 };
        let posts = FALLBACK_POSTS;
        let favorites = FALLBACK_BOOKS.slice(0, 2);

        try {
            const profiles = await supabaseGet(
                "profiles?select=id,username,bio,read_count,followers_count,following_count&limit=1",
            );
            if (profiles && profiles.length > 0) {
                const user = profiles[0];
                username = user.username;
                bio = user.bio || bio;
                stats.read = user.read_count || stats.read;
                stats.followers = user.followers_count || stats.followers;
                stats.following = user.following_count || stats.following;

                // postsテーブルのみを使い、削除済みbooksテーブルへのjoinは行わない
                const fetchedPosts = await supabaseGet(
                    `posts?profile_id=eq.${user.id}&select=id,book_id,rating,comment,created_at&order=created_at.desc&limit=10`,
                );

                if (fetchedPosts && fetchedPosts.length > 0) {
                    posts = fetchedPosts.map((p) => ({
                        id: p.id,
                        username,
                        book_title: p.book_id || "book-id未設定",
                        rating: p.rating,
                        comment: p.comment,
                        date: p.created_at
                            ? new Date(p.created_at).toLocaleDateString("ja-JP")
                            : "",
                    }));
                }
            }
        } catch (err) {
            console.error(
                "Error fetching Supabase data in SEO worker for user:",
                err,
            );
        }

        const postsHtml = posts
            .map(
                (p) => `
      <div class="post-card">
        <div class="post-header">
          <strong>${escapeHtml(p.book_title)}</strong>
          <span class="post-rating">★ ${p.rating}/5</span>
        </div>
        <p class="post-comment">"${escapeHtml(p.comment)}"</p>
        <small style="color:#888;">投稿日: ${escapeHtml(p.date)}</small>
      </div>
    `,
            )
            .join("");

        const favoritesHtml = favorites
            .map(
                (b) => `
      <div class="book-item">
        <div class="book-details">
          <p class="book-title">${escapeHtml(b.title)}</p>
          <p class="book-author">著者: ${escapeHtml(b.author)} | 評価: ★ ${escapeHtml(b.rating_avg)}</p>
        </div>
      </div>
    `,
            )
            .join("");

        const html = renderPage({
            title: `${escapeHtml(username)} のプロフィール`,
            description: `${escapeHtml(username)}さんの読書履歴、書評、お気に入り本リスト。読了数: ${stats.read}冊、フォロワー: ${stats.followers}人。`,
            content: `
        <h2>ユーザー情報</h2>
        <div style="background:#eee; padding:15px; border-radius:8px; margin-bottom:20px;">
          <h3>${escapeHtml(username)}</h3>
          <p>${escapeHtml(bio)}</p>
          <p><strong>読了:</strong> ${stats.read} 冊 | <strong>フォロワー:</strong> ${stats.followers} 人 | <strong>フォロー:</strong> ${stats.following} 人</p>
        </div>

        <h2>投稿した書評</h2>
        <div>${postsHtml.length > 0 ? postsHtml : "<p>投稿はありません。</p>"}</div>

        <h2>お気に入りの本</h2>
        <div>${favoritesHtml.length > 0 ? favoritesHtml : "<p>お気に入りの本はありません。</p>"}</div>
      `,
            jsonLd: {
                "@context": "https://schema.org",
                "@type": "ProfilePage",
                name: escapeHtml(username),
                description: escapeHtml(bio),
                interactionStatistic: [
                    {
                        "@type": "InteractionCounter",
                        interactionType: "https://schema.org/FollowAction",
                        userInteractionCount: stats.followers,
                    },
                ],
            },
        });

        res.setHeader("Content-Type", "text/html; charset=utf-8");
        return res.status(200).send(html);
    }

    // Default: Book List Page / Landing Page
    let books = FALLBACK_BOOKS;
    let recentPosts = FALLBACK_POSTS;

    try {
        // booksテーブルは廃止済みのため、ランディング表示ではフォールバック本データを利用
        const rawPosts = await supabaseGet(
            "posts?select=id,book_id,rating,comment,created_at,profiles(username)&order=created_at.desc&limit=5",
        );

        if (rawPosts && rawPosts.length > 0) {
            recentPosts = rawPosts.map((p) => ({
                id: p.id,
                username: p.profiles?.username || "匿名ユーザー",
                book_title: p.book_id || "書籍ID未設定",
                rating: p.rating,
                comment: p.comment,
                date: p.created_at
                    ? new Date(p.created_at).toLocaleDateString("ja-JP")
                    : "",
            }));
        }
    } catch (err) {
        console.error(
            "Error fetching Supabase data in SEO worker for index:",
            err,
        );
    }

    // Filter books by genre
    const yosho = books.filter((b) => b.genre === "洋書");
    const ninki = books.filter((b) => b.genre === "人気");
    const others = books.filter(
        (b) => b.genre !== "洋書" && b.genre !== "人気",
    );

    const renderBookList = (list) =>
        list
            .map(
                (b) => `
    <div class="book-item">
      ${b.cover_url ? `<img class="book-cover" src="${escapeHtml(b.cover_url)}" alt="${escapeHtml(b.title)} Cover">` : ""}
      <div class="book-details">
        <h4 class="book-title">${escapeHtml(b.title)}</h4>
        <p class="book-author">著者: ${escapeHtml(b.author)} | 評価: ★ ${escapeHtml(b.rating_avg || "評価なし")}</p>
        ${b.description ? `<p style="font-size:0.9em; color:#555;">${escapeHtml(b.description)}</p>` : ""}
      </div>
    </div>
  `,
            )
            .join("");

    const timelineHtml = recentPosts
        .map(
            (p) => `
    <div class="post-card">
      <div class="post-header">
        <strong>${escapeHtml(p.username)} さん のレビュー - 『${escapeHtml(p.book_title)}』</strong>
        <span class="post-rating">★ ${p.rating}/5</span>
      </div>
      <p class="post-comment">"${escapeHtml(p.comment)}"</p>
      <small style="color:#888;">投稿日: ${escapeHtml(p.date)}</small>
    </div>
  `,
        )
        .join("");

    const html = renderPage({
        title: "本の一覧・検索・タイムライン",
        description:
            "BookCaseは洋書や人気小説、各種文学などのジャンル別一覧、ユーザーによる書評タイムラインが確認できる本棚管理アプリケーションです。",
        content: `
      <h2>洋書</h2>
      <div>${yosho.length > 0 ? renderBookList(yosho) : "<p>該当する本がありません。</p>"}</div>

      <h2>人気</h2>
      <div>${ninki.length > 0 ? renderBookList(ninki) : "<p>該当する本がありません。</p>"}</div>

      ${others.length > 0 ? `<h2>その他のジャンル</h2><div>${renderBookList(others)}</div>` : ""}

      <h2>タイムライン (最新レビュー)</h2>
      <div>${timelineHtml.length > 0 ? timelineHtml : "<p>最近の投稿はありません。</p>"}</div>
    `,
        jsonLd: {
            "@context": "https://schema.org",
            "@type": "BookSeries",
            name: "BookCase Book Shelf",
            description:
                "Book list page featuring international, popular, and classic books with user ratings.",
            url: "https://bookcase.vercel.app/",
        },
    });

    res.setHeader("Content-Type", "text/html; charset=utf-8");
    return res.status(200).send(html);
};
