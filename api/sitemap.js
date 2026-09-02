const SITE_URL = "https://sharemarium.com";
const LASTMOD = process.env.SEO_LASTMOD || "2026-09-02";
const IS_PRODUCTION = process.env.VERCEL_ENV === "production";

function nowIsoDate() {
  return LASTMOD;
}

function sitemapUrl(loc, changefreq, priority) {
  return `  <url>\n    <loc>${loc}</loc>\n    <lastmod>${nowIsoDate()}</lastmod>\n    <changefreq>${changefreq}</changefreq>\n    <priority>${priority}</priority>\n  </url>`;
}

module.exports = async (_req, res) => {
  const urls = [
    sitemapUrl(`${SITE_URL}/`, "daily", "1.0"),
    sitemapUrl(`${SITE_URL}/privacy`, "monthly", "0.4"),
    sitemapUrl(`${SITE_URL}/terms`, "monthly", "0.4"),
    sitemapUrl(`${SITE_URL}/community-guidelines`, "monthly", "0.4"),
    sitemapUrl(`${SITE_URL}/infringement-policy`, "monthly", "0.4"),
    sitemapUrl(`${SITE_URL}/external-transmission`, "monthly", "0.4"),
    sitemapUrl(`${SITE_URL}/contact`, "monthly", "0.4"),
  ];

  const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.join("\n")}\n</urlset>\n`;

  res.setHeader("Content-Type", "application/xml; charset=utf-8");
  if (!IS_PRODUCTION) {
    res.setHeader("X-Robots-Tag", "noindex, nofollow");
  }
  res.setHeader("Cache-Control", "s-maxage=3600, stale-while-revalidate");
  return res.status(200).send(xml);
};
