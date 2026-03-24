/// Integration tests for cookie support.
/// Requires network access to httpbin.org.
module cookies;

import ddcurl.http;
import std.json;

/// In-memory cookies persist across requests
unittest
{
    scope auto client = new HTTPClient();
    client.enableCookies().setMaxRedirects(5);

    // httpbin sets a cookie and redirects to /cookies
    HTTPResponse r1 = client.get("https://httpbin.org/cookies/set?testcookie=hello123");
    assert(r1.code == 200, "Expected 200 after redirect");

    JSONValue cookies = parseJSON(r1.text)["cookies"];
    assert(cookies["testcookie"].str == "hello123", "Cookie value mismatch");

    // Cookie should persist on the next request
    HTTPResponse r2 = client.get("https://httpbin.org/cookies");
    JSONValue cookies2 = parseJSON(r2.text)["cookies"];
    assert(cookies2["testcookie"].str == "hello123", "Cookie not persisted across requests");
}

/// Cookie jar file persists across sessions
unittest
{
    import std.file : exists, remove;
    enum jarPath = "/tmp/ddcurl_test_cookies.txt";

    if (exists(jarPath))
        remove(jarPath);

    // First session: set cookie and flush to jar
    {
        scope auto c = new HTTPClient();
        c.setCookieJar(jarPath).setMaxRedirects(5);

        HTTPResponse r = c.get("https://httpbin.org/cookies/set?jarcookie=persisted");
        assert(r.code == 200);
        c.close();
    }

    assert(exists(jarPath), "Cookie jar file was not created");

    // Second session: cookies loaded from jar
    {
        scope auto c = new HTTPClient();
        c.setCookieJar(jarPath).setMaxRedirects(5);

        HTTPResponse r = c.get("https://httpbin.org/cookies");
        JSONValue cookies = parseJSON(r.text)["cookies"];
        assert(cookies["jarcookie"].str == "persisted", "Cookie not loaded from jar file");
    }

    if (exists(jarPath))
        remove(jarPath);
}

/// Cookies disabled by default — no leakage
unittest
{
    scope auto client = new HTTPClient();
    client.setMaxRedirects(5);

    client.get("https://httpbin.org/cookies/set?ghost=ignored");

    HTTPResponse r = client.get("https://httpbin.org/cookies");
    JSONValue cookies = parseJSON(r.text)["cookies"];
    assert(cookies.object.length == 0, "Cookies should be empty when disabled");
}
