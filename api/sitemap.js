const SITE_URL = "https://book-case-u9uq.vercel.app";

function nowIsoDate() {
    return new Date().toISOString().split("T")[0];
}

function sampleBookCatalog() {
    return [
        "konbini-ningen",
        "fune-wo-amu",
        "midnight-library",
        "atomic-habits",
        "baton-wa-watasareta",
        "nanji-hoshi-no-gotoku",
    ];
}

function sitemapUrl(loc, changefreq, priority) {
    return `  <url>\n    <loc>${loc}</loc>\n    <lastmod>${nowIsoDate()}</lastmod>\n    <changefreq>${changefreq}</changefreq>\n    <priority>${priority}</priority>\n  </url>`;
}

module.exports = async (_req, res) => {
    const urls = [
        sitemapUrl(`${SITE_URL}/`, "daily", "1.0"),
        sitemapUrl(`${SITE_URL}/genre/recommended`, "daily", "0.9"),
        sitemapUrl(`${SITE_URL}/genre/western`, "daily", "0.9"),
        sitemapUrl(`${SITE_URL}/genre/popular`, "daily", "0.9"),
        ...sampleBookCatalog().map((slug) =>
            sitemapUrl(`${SITE_URL}/book/${slug}`, "weekly", "0.8"),
        ),
    ];

    const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.join("\n")}\n</urlset>\n`;

    res.setHeader("Content-Type", "application/xml; charset=utf-8");
    res.setHeader("Cache-Control", "s-maxage=3600, stale-while-revalidate");
    return res.status(200).send(xml);
};
