const assert = require("node:assert/strict");
const test = require("node:test");

function responseRecorder() {
  return {
    headers: {},
    statusCode: 200,
    body: undefined,
    setHeader(name, value) {
      this.headers[name] = value;
    },
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(value) {
      this.body = value;
      return this;
    },
    send(value) {
      this.body = value;
      return this;
    },
  };
}

function loadRakuten(env = {}) {
  const { createHandler } = require("../../api/rakuten");
  return createHandler({ env });
}

test("Rakuten proxy rejects non-GET requests", async () => {
  const res = responseRecorder();
  await loadRakuten()({ method: "POST", query: {}, headers: {} }, res);
  assert.equal(res.statusCode, 405);
  assert.equal(res.body.error, "method_not_allowed");
});

test("Rakuten proxy rejects missing credentials", async () => {
  const res = responseRecorder();
  await loadRakuten()({ method: "GET", query: {}, headers: {} }, res);
  assert.equal(res.statusCode, 500);
  assert.equal(res.body.error, "rakuten_credentials_missing");
});

test("Rakuten proxy validates endpoint and pagination", async () => {
  const env = { RAKUTEN_APP_ID: "app", RAKUTEN_ACCESS_KEY: "key" };
  const invalidEndpoint = responseRecorder();
  await loadRakuten(env)(
    { method: "GET", query: { endpoint: "invalid" }, headers: {} },
    invalidEndpoint,
  );
  assert.equal(invalidEndpoint.statusCode, 400);
  assert.equal(invalidEndpoint.body.error, "invalid_endpoint");

  const invalidPage = responseRecorder();
  await loadRakuten(env)(
    { method: "GET", query: { page: "0" }, headers: {} },
    invalidPage,
  );
  assert.equal(invalidPage.statusCode, 400);
  assert.equal(invalidPage.body.error, "invalid_pagination");
});

test("Rakuten proxy returns 502 when upstream request fails", async () => {
  const handler = loadRakuten({
    RAKUTEN_APP_ID: "app",
    RAKUTEN_ACCESS_KEY: "key",
  });
  const res = responseRecorder();
  const request = require("../../api/rakuten").createHandler({
    env: { RAKUTEN_APP_ID: "app", RAKUTEN_ACCESS_KEY: "key" },
    request: async () => {
      throw new Error("timeout");
    },
  });
  assert.ok(handler);
  await request({ method: "GET", query: {}, headers: {} }, res);
  assert.equal(res.statusCode, 502);
  assert.equal(res.body.error, "rakuten_proxy_failed");
});

test("sitemap returns XML and hides non-production pages from robots", async () => {
  const previous = process.env.VERCEL_ENV;
  delete process.env.VERCEL_ENV;
  delete require.cache[require.resolve("../../api/sitemap")];
  const sitemap = require("../../api/sitemap");
  const res = responseRecorder();
  await sitemap({}, res);
  assert.equal(res.statusCode, 200);
  assert.match(res.body, /<urlset/);
  assert.equal(res.headers["X-Robots-Tag"], "noindex, nofollow");
  if (previous === undefined) delete process.env.VERCEL_ENV;
  else process.env.VERCEL_ENV = previous;
});

test("SEO handler renders the public home page", async () => {
  process.env.VERCEL_ENV = "preview";
  delete process.env.SUPABASE_URL;
  delete process.env.SUPABASE_ANON_KEY;
  delete require.cache[require.resolve("../../api/seo")];
  const seo = require("../../api/seo");
  const res = responseRecorder();
  await seo({ query: {} }, res);
  assert.equal(res.statusCode, 200);
  assert.match(res.body, /Sharemarium/);
  assert.match(res.headers["Content-Type"], /text\/html/);
});

test("SEO handler returns noindex 404 for a missing profile", async () => {
  process.env.VERCEL_ENV = "production";
  process.env.SUPABASE_URL = "https://supabase.example";
  process.env.SUPABASE_ANON_KEY = "public-key";
  const originalFetch = global.fetch;
  global.fetch = async () =>
    new Response("[]", { status: 200, headers: { "Content-Type": "application/json" } });
  delete require.cache[require.resolve("../../api/seo")];
  const seo = require("../../api/seo");
  const res = responseRecorder();
  await seo({ query: { path: "/users/missing-user" } }, res);
  global.fetch = originalFetch;
  assert.equal(res.statusCode, 404);
  assert.match(res.body, /ユーザーが見つかりません/);
  assert.match(res.body, /noindex/);
});

test("SEO handler returns noindex 404 for a private profile", async () => {
  process.env.VERCEL_ENV = "production";
  process.env.SUPABASE_URL = "https://supabase.example";
  process.env.SUPABASE_ANON_KEY = "public-key";
  const originalFetch = global.fetch;
  global.fetch = async () =>
    new Response(
      JSON.stringify([{ id: "private-user", username: "private", is_private: true }]),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  delete require.cache[require.resolve("../../api/seo")];
  const seo = require("../../api/seo");
  const res = responseRecorder();
  await seo({ query: { path: "/users/private-user" } }, res);
  global.fetch = originalFetch;
  assert.equal(res.statusCode, 404);
  assert.match(res.body, /プロフィールは非公開です/);
  assert.match(res.body, /noindex/);
});
