/// High-level implementation of a HTTP client using libcurl.
module ddcurl.http;

import core.stdc.stdlib : realloc, free;
import core.stdc.string : memcpy;
import std.outbuffer;
import std.uri;
import std.format;
import std.string;
import std.json;
import std.concurrency;
import ddcurl.libcurl;
import ddlogger;

immutable
{
    string httpHeaderAuthorization = "Authorization";
}

//
// Basic HTTP client using libcurl
//

private
struct MemoryBuffer
{
    void *buffer;
    size_t bufsize;
    size_t index;
    
    ~this()
    {
        close();
    }
    
    void reset()
    {
        index = 0;
    }
    
    void append(void *data, size_t size)
    {
        if (index + size >= bufsize)
            resize(bufsize + (bufsize - index) + size);
        memcpy(buffer + index, data, size);
        index += size;
    }
    
    void resize(size_t newsize)
    {
        buffer = realloc(buffer, newsize);
        if (buffer == null)
            throw new Exception("Failed to allocate memory buffer");
        bufsize = newsize;
    }
    
    void close()
    {
        if (buffer) free(buffer);
        buffer = null;
    }
    
    string toString() const
    {
        return (cast(immutable(char)*)buffer)[0..index];
    }
}
unittest
{
    static immutable ubyte[3] data = [ 1, 2, 3 ];
    MemoryBuffer mem;
    mem.append(cast(void*)data.ptr, data.length);
    mem.append(cast(void*)data.ptr, data.length);
    assert(mem.bufsize == 6);
    assert(mem.buffer);
    assert((cast(ubyte*)mem.buffer)[0] == 1);
    assert((cast(ubyte*)mem.buffer)[1] == 2);
    assert((cast(ubyte*)mem.buffer)[2] == 3);
    assert((cast(ubyte*)mem.buffer)[3] == 1);
    assert((cast(ubyte*)mem.buffer)[4] == 2);
    assert((cast(ubyte*)mem.buffer)[5] == 3);
}

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
        
        curlMain = curl_easy_init();
        if (curlMain == null)
            throw new Exception("curl_easy_init failed");
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
        logTrace("GET %s", path);
        
        if (path == null)
            throw new Exception("Path is empty");
        
        CURL *curl = curl_easy_duphandle(curlMain);
        if (curl == null)
            throw new Exception("curl_easy_duphandle returned null");
        
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
        logTrace("POST %s with payload of %u bytes", path, payload.length);
        
        if (path == null)
            throw new Exception("Path is empty");
        
        CURL *curl = curl_easy_duphandle(curlMain);
        if (curl == null)
            throw new Exception("curl_easy_duphandle returned null");
        
        curl_easy_setopt(curl, CURLOPT_POST, 1L);
        
        // Now specify the POST data
        if (payload)
        {
            // NOTE: Documentation say that for -1 (default), strlen is used.
            //       But the example does strlen() for CURLOPT_POSTFIELDSIZE.
            //       The example for CURLOPT_POSTFIELDSIZE_LARGE does not.
            //       Let's trust the doc and assume it's same to do this.
            curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, cast(long)payload.length);
            curl_easy_setopt(curl, CURLOPT_POSTFIELDS, payload.ptr );
        }
        else
        {
            curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, 0L);
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
    MemoryBuffer memory;
    
    HTTPResponse send(CURL *handle, string path)
    {
        scope string fullPath = baseUrl ? baseUrl ~ path : path;
        scope immutable(char)* full = toStringz( fullPath );
        
        curl_easy_setopt(handle, CURLOPT_URL, full);
        //curl_easy_setopt(handle, CURLOPT_USERPWD, "user:pass");
        
        // Set options
        curl_easy_setopt(handle, CURLOPT_TCP_KEEPALIVE, 1L);
        curl_easy_setopt(handle, CURLOPT_MAXREDIRS,     curlMaxRedirects);
        curl_easy_setopt(handle, CURLOPT_VERBOSE,       curlVerbose);
        curl_easy_setopt(handle, CURLOPT_SSL_VERIFYPEER, curlVerifyPeers);
        curl_easy_setopt(handle, CURLOPT_TIMEOUT_MS,    curlTimeoutMs);
        
        // Set user pointer
        memory.reset(); // reset index
        curl_easy_setopt(handle, CURLOPT_WRITEDATA, &memory);
        
        // Set read function
        curl_easy_setopt(handle, CURLOPT_WRITEFUNCTION, &readResponse);
        
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
        }
        
        // Set user agent
        if (userAgent)
            curl_easy_setopt(handle, CURLOPT_USERAGENT, toStringz( userAgent ));
        
        // 
        CURLcode code = curl_easy_perform(handle);
        if (code)
        {
            string em = curlErrorMessage(code);
            logError("curl error: (%d) '%s' with '%s'", code, em, fullPath);
            throw new Exception(em);
        }
        
        long response_code;
        curl_easy_getinfo(handle, CURLINFO_RESPONSE_CODE, &response_code);
        
        HTTPResponse response = void;
        response.code = cast(int)response_code;
        response.text = memory.toString();
        
        if (slist_headers)
            curl_slist_free_all(slist_headers);
        
        curl_easy_cleanup(handle);
        return response;
    }
    
    extern (C)
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