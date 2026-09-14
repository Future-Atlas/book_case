const assert = require("node:assert/strict");
const path = require("node:path");
const { pathToFileURL } = require("node:url");
const test = require("node:test");

const smokeModuleUrl = pathToFileURL(
  path.join(__dirname, "../../scripts/production-smoke.mjs"),
).href;

async function loadSmokeModule() {
  return import(smokeModuleUrl);
}

test("production smoke checks cover the required public URLs", async () => {
  const { smokeChecks } = await loadSmokeModule();
  assert.deepEqual(
    smokeChecks.map((check) => check.path),
    ["/", "/robots.txt", "/sitemap.xml", "/ads.txt"],
  );
});

test("response validation rejects non-success responses", async () => {
  const { smokeChecks, validateResponse } = await loadSmokeModule();
  const response = new Response("unavailable", {
    status: 503,
    headers: { "content-type": "text/plain" },
  });

  assert.throws(
    () => validateResponse(smokeChecks[0], response, "unavailable"),
    /HTTP 503/,
  );
});

test("response validation checks content type and body markers", async () => {
  const { smokeChecks, validateResponse } = await loadSmokeModule();
  const robots = smokeChecks.find((check) => check.path === "/robots.txt");

  assert.throws(
    () =>
      validateResponse(
        robots,
        new Response("User-agent: *", {
          status: 200,
          headers: { "content-type": "text/html" },
        }),
        "User-agent: *",
      ),
    /unexpected content-type/,
  );

  assert.throws(
    () =>
      validateResponse(
        robots,
        new Response("not robots", {
          status: 200,
          headers: { "content-type": "text/plain; charset=utf-8" },
        }),
        "not robots",
      ),
    /expected marker/,
  );

  assert.doesNotThrow(() =>
    validateResponse(
      robots,
      new Response("User-agent: *\nAllow: /", {
        status: 200,
        headers: { "content-type": "text/plain; charset=utf-8" },
      }),
      "User-agent: *\nAllow: /",
    ),
  );
});

test("endpoint check retries transient failures", async () => {
  const { checkEndpoint, smokeChecks } = await loadSmokeModule();
  const home = smokeChecks.find((check) => check.path === "/");
  let calls = 0;
  const fetchImpl = async () => {
    calls += 1;
    if (calls === 1) {
      return new Response("temporary", {
        status: 503,
        headers: { "content-type": "text/plain" },
      });
    }
    return new Response("<!doctype html><html><body>Sharemarium</body></html>", {
      status: 200,
      headers: { "content-type": "text/html; charset=utf-8" },
    });
  };

  await checkEndpoint("https://example.com", home, {
    attempts: 2,
    retryDelayMs: 0,
    timeoutMs: 1000,
    fetchImpl,
  });
  assert.equal(calls, 2);
});
