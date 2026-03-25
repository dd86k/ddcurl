/// High-level implementation of a HTTP client using libcurl.
module ddcurl.http;

import core.stdc.config : c_long;
import std.outbuffer;
import std.uri;
import std.format;
import std.string;
import std.json;
import std.concurrency;
import ddcurl.libcurl;
import ddcurl.utils;
import ddlogger;
public import ddcurl.websocket : WebSocket;

immutable
{
    string httpHeaderAuthorization = "Authorization";
}

//
// Basic HTTP client using libcurl
//

class HTTPPostData
{
    this()
    {
        buffer = new OutBuffer();
    }
    
    void add(string name, string value)
    {
        if (buffer.offset) buffer.write('&');
        buffer.write(name);
        buffer.write('=');
        buffer.write(value);
    }
    void add(string name, ulong value)
    {
        if (buffer.offset) buffer.write('&');
        buffer.write(name);
        buffer.write('=');
        buffer.writef("%u", value);
    }
    void add(string name, int value)
    {
        if (buffer.offset) buffer.write('&');
        buffer.write(name);
        buffer.write('=');
        buffer.writef("%d", value);
    }

    override
    string toString() const
    {
        return cast(string)buffer.toBytes();
    }
    
private:
    OutBuffer buffer;
}

struct HTTPResponse
{
    int code;
    string text;
}

class HTTPClient
{
    this()
    {
        curlLoad(); // Depends on libcurl
    }

    ~this()
    {
        close();
    }

    /// Clean up the persistent curl handle and write cookies to the jar file.
    void close()
    {
        if (curl)
        {
            curl_easy_cleanup(curl);
            curl = null;
        }
    }
    
    /// Set CURL's verbose flag.
    /// Params: verbose = When enabled, CURL outputs information via stderr.
    typeof(this) setVerbose(bool verbose)
    {
        curlVerbose = cast(long)verbose;
        return this;
    }
    
    /// Set a base URL that will be used in all future requests.
    /// Params:
    ///   base = Prefix, including protocol and domain
    typeof(this) setBaseUrl(string base)
    {
        baseUrl = base;
        return this;
    }
    
    /// Set the user-agent string that will be used in all future requests.
    /// Params:
    ///   agent = User agent string.
    typeof(this) setUserAgent(string agent)
    {
        userAgent = agent;
        return this;
    }
    
    /// Add header to all future requests.
    /// Params:
    ///   name = Field name.
    ///   value = Value.
    typeof(this) addHeader(string name, string value)
    {
        headers[name] = value;
        return this;
    }
    // remove default header
    /// Remove header from all future requests.
    /// Params:
    ///   name = Field name.
    typeof(this) removeHeader(string name)
    {
        headers.remove(name);
        return this;
    }
    
    /// Set peer verification option.
    /// Params:
    ///   v = True to perform peer verification.
    typeof(this) setVerifyPeers(bool v)
    {
        curlVerifyPeers = cast(c_long)v;
        return this;
    }
    
    /// Set the maximum amount of redirections allowed.
    /// Params:
    ///   n = Number of redirections. -1 being infinite.
    typeof(this) setMaxRedirects(int n)
    {
        curlMaxRedirects = n;
        return this;
    }
    
    /// Set the timeout.
    /// Params:
    ///   ms = Timeout in milliseconds. 0 for no timeouts.
    typeof(this) setTimeout(long ms)
    {
        curlTimeoutMs = cast(c_long)ms;
        return this;
    }
    
    /// Enable in-memory cookie handling.
    ///
    /// Cookies received via Set-Cookie headers are stored and sent on
    /// subsequent requests. Cookies are not persisted to disk.
    typeof(this) enableCookies()
    {
        cookieFile = "";
        return this;
    }

    /// Set a cookie jar file for persistent cookies.
    ///
    /// Cookies are read from the file at the start and written back on close.
    /// Also enables in-memory cookie handling for the session.
    /// Params:
    ///   path = File path. The file is created if it does not exist.
    typeof(this) setCookieJar(string path)
    {
        cookieFile = path;
        cookieJar = path;
        return this;
    }

    /// Get the value set of a previously set header field name.
    /// Params:
    ///   name = Header field name.
    /// Returns: String pointer. If null, header entry does not exist.
    string* getHeader(string name)
    {
        return name in headers;
    }
    
    /// Perform a GET request.
    /// Params:
    ///   path = Full or postfix URL path.
    /// Returns: HTTP response.
    HTTPResponse get(string path = null) // TODO: get parameters
    {
        string canon = canonicalPath(path);

        logDebugging("GET %s", canon);
        
        initHandle();
        // Helps when previous call was a POST
        curl_set_option(curl, CURLOPT_POST, 0);
        
        return send(canon);
    }

    /// Perform a POST request.
    ///
    /// Best used with HTTPPostData to help with encoding POST HTML forms.
    /// Params:
    ///   path = Full or postfix URL path.
    ///   payload = Payload. Can be empty.
    /// Returns: HTTP response.
    HTTPResponse post(string path = null, string payload = null)
    {
        string canon = canonicalPath(path);

        logDebugging("POST %s (%u bytes)", canon, payload.length);

        initHandle();

        // Set POST option
        curl_set_option(curl, CURLOPT_POST, 1);
        
        // Now specify the POST data
        if (payload)
        {
            // NOTE: Documentation say that for -1 (default), strlen is used.
            //       But the example does strlen() for CURLOPT_POSTFIELDSIZE.
            //       The example for CURLOPT_POSTFIELDSIZE_LARGE does not.
            //       Let's trust the doc and assume it's same to do this.
            curl_set_option(curl, CURLOPT_POSTFIELDSIZE, payload.length);
            curl_set_option(curl, CURLOPT_POSTFIELDS,    payload.ptr);
        }
        else // Empty payload
        {
            curl_set_option(curl, CURLOPT_POSTFIELDSIZE, 0);
        }
        
        return send(canon);
    }
    
    // perform a post request with an associative array payload
    /*
    HTTPResponse post(string path, ...)
    {
        import core.vararg;
        
        size_t argcount = _arguments.length;
        if (argcount == 0)
            return post(path, null);
        if (argcount % 2)
            throw new Exception("Odd count of arguments");
        
        scope HTTPPostData payload = new HTTPPostData();
        
    Larg:
        string field = va_arg!string(_argptr);
        string value = va_arg!string(_argptr);
        payload.add(field, value);
        if (argcount - 2 > 0)
        {
            argcount -= 2;
            goto Larg;
        }
        
        return post(path, payload.toString());
    }
    */
    
    /// Connect to a WebSocket.
    ///
    /// Protocols: ws://, wss://
    /// Returns: WebSocket connection.
    WebSocket connectSocket(string url)
    {
        // Dynamic binding loads ws functions optionally; they may be null
        version (DynamicBinding)
        {
            if (curl_ws_recv == null || curl_ws_send == null)
                throw new Exception("WebSockets are unavailable");
        }
        
        // WebSocket needs its own handle (CONNECT_ONLY mode)
        CURL *wscurl = curl_easy_init();
        if (wscurl == null)
            throw new CurlException("curl_easy_init failed");
        
        // Merge base path if available
        string path = canonicalPath(url);
        
        curl_set_option(wscurl, CURLOPT_URL, path.toStringz());
        curl_set_option(wscurl, CURLOPT_CONNECT_ONLY, 2); // WS style
        curl_set_option(wscurl, CURLOPT_MAXREDIRS, curlMaxRedirects);
        curl_set_option(wscurl, CURLOPT_SSL_VERIFYPEER, curlVerifyPeers);
        curl_set_option(wscurl, CURLOPT_SSL_VERIFYHOST, curlVerifyPeers);
        curl_set_option(wscurl, CURLOPT_TIMEOUT_MS, curlTimeoutMs);
        curl_set_option(wscurl, CURLOPT_VERBOSE, curlVerbose);
        
        // Add headers
        curl_slist *curl_headers = addAllHeaders(wscurl);
        
        // Perform HTTP call, curl manages the upgrade
        CURLcode code = curl_easy_perform(wscurl);
        if (code)
            throw new CurlException(code, wscurl);

        return WebSocket(wscurl, curl_headers);
    }
    
private:
    CURL *curl;
    string userAgent;
    string baseUrl;
    string[string] headers;
    
    // Cookie support
    string cookieFile; // null = disabled, "" = in-memory only, path = file
    string cookieJar;  // null = disabled, path = write cookies on cleanup
    
    char[CURL_ERROR_SIZE] error_buffer;
    
    c_long curlVerbose;
    c_long curlMaxRedirects = 5;
    c_long curlTimeoutMs = 10_000;
    c_long curlVerifyPeers = 1;
    MemoryBuffer memorybuf;
    
    // Initialize the persistent curl handle (lazy)
    void initHandle()
    {
        if (curl == null)
        {
            curl = curl_easy_init();
            if (curl == null)
                throw new CurlException("curl_easy_init returned null");
        }
    }
    
    // Get the actual full path
    string canonicalPath(string suffix)
    {
        if (baseUrl && suffix) // BaseURL + Suffix = Full URL
            return baseUrl ~ suffix;
        else if (suffix) // Suffix only = Full URL
            return suffix;
        else if (baseUrl) // BaseUrl = Full URL
            return baseUrl;
        else // Neither is set
            throw new Exception("Path is empty and BaseURL is unset");
    }
    
    // Add headers and return slist to be freed later
    curl_slist* addAllHeaders(CURL *handle)
    {
        // No headers to add, nothing to free later
        if (headers.length == 0)
            return null;
        
        // Required
        curl_set_option(handle, CURLOPT_ERRORBUFFER, error_buffer.ptr);
        
        curl_slist *curl_headers;
        foreach (key, value; headers)
        {
            char[256] buffer = void;
            char[] header = sformat(buffer, "%s: %s", key, value);
            
            // Strings are duplicated within cURL
            curl_slist *temp = curl_slist_append(curl_headers, header.toStringz());
            if (temp == null)
            {
                curl_slist_free_all(curl_headers);
                throw new CurlException(error_buffer);
            }
            
            curl_headers = temp;
        }
        
        if (curl_headers)
            curl_set_option(handle, CURLOPT_HTTPHEADER, curl_headers);
        
        return curl_headers;
    }
    
    HTTPResponse send(string path)
    {
        assert(curl);
        assert(path);
        
        logTrace("handle=%s path=%s", curl, path);
        
        // Set options
        curl_set_option(curl, CURLOPT_URL, path.toStringz());
        curl_set_option(curl, CURLOPT_TCP_KEEPALIVE, 1); // forgot what this fixes
        curl_set_option(curl, CURLOPT_FOLLOWLOCATION, cast(c_long)(curlMaxRedirects != 0));
        curl_set_option(curl, CURLOPT_MAXREDIRS, curlMaxRedirects);
        curl_set_option(curl, CURLOPT_VERBOSE, curlVerbose);
        curl_set_option(curl, CURLOPT_SSL_VERIFYPEER, curlVerifyPeers);
        curl_set_option(curl, CURLOPT_SSL_VERIFYHOST, curlVerifyPeers);
        curl_set_option(curl, CURLOPT_TIMEOUT_MS, curlTimeoutMs);
        curl_set_option(curl, CURLOPT_ERRORBUFFER, error_buffer.ptr);
        
        // Set read function with user pointer
        curl_set_option(curl, CURLOPT_WRITEFUNCTION, &readResponse);
        curl_set_option(curl, CURLOPT_WRITEDATA, this);
        
        // Cookie handling
        if (cookieFile !is null)
            curl_set_option(curl, CURLOPT_COOKIEFILE, cookieFile.toStringz());
        if (cookieJar !is null)
            curl_set_option(curl, CURLOPT_COOKIEJAR, cookieJar.toStringz());
        
        // Add headers
        curl_slist *curl_headers = addAllHeaders(curl);
        
        // Set user agent
        if (userAgent)
            curl_set_option(curl, CURLOPT_USERAGENT, userAgent.toStringz());
        
        // Perform request
        memorybuf.reset();
        CURLcode code = curl_easy_perform(curl);
        if (code)
            throw new CurlException(code);
        
        // Get response code
        c_long response_code;
        code = curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response_code);
        if (code)
            throw new CurlException(code);
        
        // Cleanup headers only (handle stays alive)
        if (curl_headers)
            curl_slist_free_all(curl_headers);
        
        // Make up response, memory buffer holds its own memory buffer that
        // it copied from reading the response
        HTTPResponse response = HTTPResponse(
            cast(int)response_code,
            memorybuf.toString()
        );
        return response;
    }
}

// "[...] this callback gets called many times and each invoke delivers"
// "another chunk of data. ptr points to the delivered data, and the size"
// "of that data is nmemb; size is always 1."
// Observed: nmemb is always 1, size varies.
private
extern (C) // ABI issues otherwise
size_t readResponse(void *ptr, size_t size, size_t nmemb, void *userdata)
{
    logTrace("ptr=%s size=%u nmemb=%u userdata=%s", ptr, size, nmemb, userdata);
    assert(userdata, "userdata null");
    if (ptr == null || size == 0 || nmemb == 0)
        return 0;
    size_t realsize = size * nmemb;
    HTTPClient client = cast(HTTPClient)userdata;
    client.memorybuf.append(ptr, realsize);
    return realsize;
}
