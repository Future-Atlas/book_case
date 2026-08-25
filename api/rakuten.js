const { requestRakuten } = require("./_rakuten_request");

const RAKUTEN_APP_ID = process.env.RAKUTEN_APP_ID || "";
const RAKUTEN_ACCESS_KEY = process.env.RAKUTEN_ACCESS_KEY || "";
const RAKUTEN_REFERER =
  process.env.RAKUTEN_REFERER || "https://www.sharemarium.com/";
const RATE_LIMIT_WINDOW_MS = 60 * 1000;
const RATE_LIMIT_MAX_REQUESTS = 30;
const requestCounts = new Map();

const ENDPOINTS = {
  book: "https://openapi.rakuten.co.jp/services/api/BooksBook/Search/20170404",
  foreign:
    "https://openapi.rakuten.co.jp/services/api/BooksForeignBook/Search/20170404",
};

module.exports = async (req, res) => {
  if (req.method !== "GET") {
    res.setHeader("Allow", "GET");
    return res.status(405).json({ error: "method_not_allowed" });
  }

  const forwardedFor = String(req.headers["x-forwarded-for"] || "");
  const realIp = String(req.headers["x-real-ip"] || "").trim();
  const clientIp = realIp || forwardedFor.split(",")[0].trim() || "unknown";
  const now = Date.now();
  const current = requestCounts.get(clientIp);
  if (!current || now - current.startedAt >= RATE_LIMIT_WINDOW_MS) {
    requestCounts.set(clientIp, { startedAt: now, count: 1 });
  } else {
    current.count += 1;
    if (current.count > RATE_LIMIT_MAX_REQUESTS) {
      res.setHeader("Retry-After", "60");
      return res.status(429).json({ error: "rate_limit_exceeded" });
    }
  }

  if (!RAKUTEN_APP_ID || !RAKUTEN_ACCESS_KEY) {
    return res.status(500).json({
      error: "rakuten_credentials_missing",
      message: "Rakuten credentials are not configured on the server.",
    });
  }

  const endpoint = String(req.query.endpoint || "book");
  if (!Object.hasOwn(ENDPOINTS, endpoint)) {
    return res.status(400).json({ error: "invalid_endpoint" });
  }
  const baseUrl = ENDPOINTS[endpoint];

  const passthrough = { ...req.query };
  delete passthrough.endpoint;
  const allowedParameters = new Set([
    "page",
    "hits",
    "booksGenreId",
    "title",
    "author",
    "publisherName",
    "keyword",
    "isbn",
    "sort",
  ]);

  const query = new URLSearchParams({
    format: "json",
    applicationId: RAKUTEN_APP_ID,
    accessKey: RAKUTEN_ACCESS_KEY,
  });

  for (const [key, value] of Object.entries(passthrough)) {
    if (!allowedParameters.has(key)) continue;
    if (Array.isArray(value)) {
      value.slice(0, 1).forEach((item) =>
        query.append(key, String(item).slice(0, 200)),
      );
    } else if (value != null && String(value).length > 0) {
      query.set(key, String(value).slice(0, 200));
    }
  }

  const page = Number(query.get("page") || 1);
  const hits = Number(query.get("hits") || 10);
  if (
    !Number.isInteger(page) ||
    page < 1 ||
    page > 100 ||
    !Number.isInteger(hits) ||
    hits < 1 ||
    hits > 30
  ) {
    return res.status(400).json({ error: "invalid_pagination" });
  }

  const url = `${baseUrl}?${query.toString()}`;

  try {
    const response = await requestRakuten(url, {
      origin: RAKUTEN_REFERER,
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
