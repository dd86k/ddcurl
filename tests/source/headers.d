/// Integration tests for request header handling.
/// Requires network access to httpbin.org.
module headers;

import ddcurl.http;
import std.json;

/// Removing a header on a reused handle must not re-send it.
///
/// Regression: addAllHeaders returned early on an empty header set without
/// touching CURLOPT_HTTPHEADER. Because the handle is persistent and send()
/// frees the previous request's slist, the option was left dangling and the
/// next header-less request re-transmitted the previous request's headers.
unittest
{
    scope auto client = new HTTPClient();
    client.setMaxRedirects(5);

    // First request carries a custom header.
    client.addHeader("X-Ddcurl-Test", "present");
    HTTPResponse r1 = client.get("https://httpbin.org/headers");
    assert(r1.code == 200, "Expected 200 for first request");

    JSONValue h1 = parseJSON(r1.text)["headers"];
    assert("X-Ddcurl-Test" in h1.object, "Custom header should be sent on first request");
    assert(h1["X-Ddcurl-Test"].str == "present", "Custom header value mismatch");

    // Remove it, then reuse the same handle for a header-less request.
    client.removeHeader("X-Ddcurl-Test");
    HTTPResponse r2 = client.get("https://httpbin.org/headers");
    assert(r2.code == 200, "Expected 200 for second request");

    JSONValue h2 = parseJSON(r2.text)["headers"];
    assert(("X-Ddcurl-Test" in h2.object) is null,
        "Removed header must not be re-sent from the freed slist");
}
