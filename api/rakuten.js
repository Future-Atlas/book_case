const { requestRakuten } = require("./_rakuten_request");

const RAKUTEN_APP_ID = process.env.RAKUTEN_APP_ID || "";
const RAKUTEN_ACCESS_KEY = process.env.RAKUTEN_ACCESS_KEY || "";
const RAKUTEN_REFERER =
  process.env.RAKUTEN_REFERER || "https://www.sharemarium.com/";

const ENDPOINTS = {
  book: "https://openapi.rakuten.co.jp/services/api/BooksBook/Search/20170404",
  foreign:
    "https://openapi.rakuten.co.jp/services/api/BooksForeignBook/Search/20170404",
};

module.exports = async (req, res) => {
  if (!RAKUTEN_APP_ID || !RAKUTEN_ACCESS_KEY) {
    return res.status(500).json({
      error: "rakuten_credentials_missing",
      message: "Rakuten credentials are not configured on the server.",
    });
  }

  const endpoint = String(req.query.endpoint || "book");
  const baseUrl = ENDPOINTS[endpoint] || ENDPOINTS.book;

  const passthrough = { ...req.query };
  delete passthrough.endpoint;

  const query = new URLSearchParams({
    format: "json",
    applicationId: RAKUTEN_APP_ID,
    accessKey: RAKUTEN_ACCESS_KEY,
  });

  for (const [key, value] of Object.entries(passthrough)) {
    if (Array.isArray(value)) {
      value.forEach((item) => query.append(key, String(item)));
    } else if (value != null && String(value).length > 0) {
      query.set(key, String(value));
    }
  }

  const url = `${baseUrl}?${query.toString()}`;

  try {
    const response = await requestRakuten(url, {
      referer: RAKUTEN_REFERER,
      userAgent:
        "Sharemarium-Rakuten-Proxy/1.0 (+https://www.sharemarium.com)",
    });

    const body = await response.text();
    res.setHeader(
      "Cache-Control",
      "public, s-maxage=120, stale-while-revalidate=300",
    );
    res.setHeader("Content-Type", "application/json; charset=utf-8");
    res.setHeader("X-Rakuten-Proxy-Transport", "node-http");
    return res.status(response.status).send(body);
  } catch (error) {
    return res.status(502).json({
      error: "rakuten_proxy_failed",
      message: error instanceof Error ? error.message : String(error),
    });
  }
};
