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
        curlVerifyPeers = cast(long)v;
        return this;
    }
    
    /// Set the maximum amount of redirections allowed.
    /// Params:
    ///   n = Number of redirections. -1 being infinite.
    typeof(this) setMaxRedirects(long n)
    {
        curlMaxRedirects = n;
        return this;
    }
    
    /// Set the timeout.
    /// Params:
    ///   ms = Timeout in milliseconds. 0 for no timeouts.
    typeof(this) setTimeout(long ms)
    {
        curlTimeoutMs = ms;
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
    HTTPResponse get(string path) // TODO: get parameters
    {
        logDebugging("GET %s", path);
        
        if (path == null)
            throw new Exception("Path is empty");
        
        CURL *curl = curl_easy_init();
        if (curl == null)
            throw new Exception("curl_easy_init returned null");
        
        return send(curl, path);
    }
    
    /// Perform a POST request.
    ///
    /// Best used with HTTPPostData to help with encoding POST HTML forms.
    /// Params:
    ///   path = Full or postfix URL path.
    ///   payload = Payload. Can be empty.
    /// Returns: HTTP response.
    HTTPResponse post(string path, string payload)
    {
        logDebugging("POST %s (%u bytes)", path, payload.length);
        
        if (path == null)
            throw new Exception("Path is empty");
        
        CURL *curl = curl_easy_init();
        if (curl == null)
            throw new Exception("curl_easy_init returned null");
        
        CURLcode code = void;
        code = curl_easy_setopt(curl, CURLOPT_POST, 1L);
        if (code)
            throw new CurlEasyException(code, "curl_easy_setopt");
        
        // Now specify the POST data
        if (payload)
        {
            // NOTE: Documentation say that for -1 (default), strlen is used.
            //       But the example does strlen() for CURLOPT_POSTFIELDSIZE.
            //       The example for CURLOPT_POSTFIELDSIZE_LARGE does not.
            //       Let's trust the doc and assume it's same to do this.
            code = curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, cast(long)payload.length);
            if (code)
                throw new CurlEasyException(code, "curl_easy_setopt");
            
            code = curl_easy_setopt(curl, CURLOPT_POSTFIELDS, payload.ptr );
            if (code)
                throw new CurlEasyException(code, "curl_easy_setopt");
        }
        else
        {
            code = curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, 0L);
            if (code)
                throw new CurlEasyException(code, "curl_easy_setopt");
            
        }
        
        return send(curl, path);
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
    
private:
    string userAgent;
    string baseUrl;
    string[string] headers;
    
    CURL *curlMain;
    long curlVerbose;
    long curlMaxRedirects = 5;
    long curlTimeoutMs;
    long curlVerifyPeers = 1;
    MemoryBuffer memorybuf;
    
    HTTPResponse send(CURL *handle, string path)
    {
        assert(handle);
        assert(path);
        
        scope string fullPath = baseUrl ? baseUrl ~ path : path;
        logTrace("handle=%s path=%s", handle, fullPath);
        
        scope immutable(char)* full = toStringz( fullPath );
        
        CURLcode code = void;
        
        code = curl_easy_setopt(handle, CURLOPT_URL, full);
        if (code)
            throw new CurlEasyException(code, "curl_easy_setopt");
        //curl_easy_setopt(handle, CURLOPT_USERPWD, "user:pass");
        
        // Set options
        curl_easy_setopt(handle, CURLOPT_TCP_KEEPALIVE,  1L);
        if (code)
            throw new CurlEasyException(code, "curl_easy_setopt");
        curl_easy_setopt(handle, CURLOPT_MAXREDIRS,      curlMaxRedirects);
        if (code)
            throw new CurlEasyException(code, "curl_easy_setopt");
        curl_easy_setopt(handle, CURLOPT_VERBOSE,        curlVerbose);
        if (code)
            throw new CurlEasyException(code, "curl_easy_setopt");
        curl_easy_setopt(handle, CURLOPT_SSL_VERIFYPEER, curlVerifyPeers);
        if (code)
            throw new CurlEasyException(code, "curl_easy_setopt");
        curl_easy_setopt(handle, CURLOPT_TIMEOUT_MS,     curlTimeoutMs);
        if (code)
            throw new CurlEasyException(code, "curl_easy_setopt");
        
        // Set user pointer
        memorybuf.reset();
        curl_easy_setopt(handle, CURLOPT_WRITEDATA, &memorybuf);
        if (code)
            throw new CurlEasyException(code, "curl_easy_setopt");
        
        // Set read function
        curl_easy_setopt(handle, CURLOPT_WRITEFUNCTION, &readResponse);
        if (code)
            throw new CurlEasyException(code, "curl_easy_setopt");
        
        // Set headers
        curl_slist *slist_headers;
        if (headers.length)
        {
            foreach (key, value; headers)
            {
                char[256] buffer = void;
                char[] header = sformat(buffer, "%s: %s", key, value);
                
                slist_headers = curl_slist_append(slist_headers, toStringz( header ));
                if (slist_headers == null)
                    throw new Exception("curl_slist_append failed");
            }
            
            curl_easy_setopt(handle, CURLOPT_HTTPHEADER, slist_headers);
            if (code)
                throw new CurlEasyException(code, "curl_easy_setopt");
        }
        
        // Set user agent
        if (userAgent)
        {
            curl_easy_setopt(handle, CURLOPT_USERAGENT, toStringz( userAgent ));
            if (code)
                throw new CurlEasyException(code, "curl_easy_setopt");
        }
        
        // Perform request
        code = curl_easy_perform(handle);
        if (code)
            throw new CurlEasyException(code, "curl_easy_perform");
        
        // Get response code
        c_long response_code;
        code = curl_easy_getinfo(handle, CURLINFO_RESPONSE_CODE, &response_code);
        if (code)
            throw new CurlEasyException(code, "curl_easy_getinfo");
        
        // Cleanup
        if (slist_headers)
            curl_slist_free_all(slist_headers);
        curl_easy_cleanup(handle);
        
        // NOTE: memory buffer holds its own memory buffer
        HTTPResponse response = HTTPResponse(
            cast(int)response_code,
            memorybuf.toString()
        );
        return response;
    }
    
    static
    size_t readResponse(void *content, size_t size, size_t nmemb, void *userp)
    {
        size_t realsize = size * nmemb;
        MemoryBuffer *mem = cast(MemoryBuffer*)userp;
        logTrace("content=%s size=%u nmemb=%u userp=%s", content, size, nmemb, userp);
        mem.append(content, realsize);
        return realsize;
    }
}

version (none)
unittest
{
    import std.stdio;
    // 
    scope HTTPClient client = new HTTPClient()
        .setUserAgent("Test/0.0.0");
    
    HTTPResponse res = client.get(
        "https://jsonplaceholder.typicode.com/todos/1"
    );
    // {
    //   "userId": 1,
    //   "id": 1,
    //   "title": "delectus aut autem",
    //   "completed": false
    // }
    writeln("Test: GET /todos/1\n", res.text);
    
    client.setBaseUrl("https://jsonplaceholder.typicode.com");
    res = client.get("/todos/2");
    // {
    //   "userId": 1,
    //   "id": 2,
    //   "title": "quis ut nam facilis et officia qui",
    //   "completed": false
    // }
    writeln("Test: GET /todos/2\n", res.text);
    
    /*
    res = client.post("/posts",
        "title",    "test",
        "body",     "dd",
        "userId",   "1",
    );
    // {
    //   "id": 101,
    //   "title": "foo",
    //   "body": "bar",
    //   "userId": 1
    // }
    writeln("test2: ", res.text);
    */
}