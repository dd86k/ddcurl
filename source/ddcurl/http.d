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
    
    /*
    void close()
    {
        if (buffer) free(buffer);
        buffer = null;
    }
    */
    
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
    
    typeof(this) setBaseUrl(string base)
    {
        baseUrl = base;
        return this;
    }
    
    typeof(this) setUserAgent(string agent)
    {
        userAgent = agent;
        return this;
    }
    
    // add default header to requests
    typeof(this) addHeader(string name, string value)
    {
        headers[name] = value;
        return this;
    }
    // remove default header
    typeof(this) removeHeader(string name)
    {
        headers.remove(name);
        return this;
    }
    
    // Get header value
    string* getHeader(string name)
    {
        return name in headers;
    }
    
    // perform a get request
    HTTPResponse get(string path) // TODO: get parameters
    {
        logTrace("GET %s", path);
        CURL *curl = curl_easy_duphandle(curlMain);
        return send(curl, path);
    }
    
    // perform a post request with an associative array payload
    HTTPResponse post(string path, string payload)
    {
        logTrace("POST %s with payload of %u bytes", path, payload.length);
        
        CURL *curl = curl_easy_duphandle(curlMain);
        
        // Now specify the POST data
        if (payload)
        {
            curl_easy_setopt(curl, CURLOPT_POST, 1L);
            curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, cast(long)payload.length);
            curl_easy_setopt(curl, CURLOPT_POSTFIELDS, toStringz( payload ));
        }
        else
        {
            curl_easy_setopt(curl, CURLOPT_POST, 1L);
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
    
    void setVerbose(bool verbose)
    {
        curlVerbose = cast(long)verbose;
    }
    
private:
    string userAgent;
    string baseUrl;
    string[string] headers;
    
    CURL *curlMain;
    long curlVerbose;
    MemoryBuffer memory;
    
    HTTPResponse send(CURL *handle, string path)
    {
        assert(baseUrl);
        assert(path);
        
        string fullPath = baseUrl ~ path;
        immutable(char)* full = toStringz( baseUrl ~ path );
        
        curl_easy_setopt(handle, CURLOPT_URL, full);
        //curl_easy_setopt(handle, CURLOPT_USERPWD, "user:pass");
        curl_easy_setopt(handle, CURLOPT_MAXREDIRS, 5L);
        curl_easy_setopt(handle, CURLOPT_TCP_KEEPALIVE, 1L);
        curl_easy_setopt(handle, CURLOPT_VERBOSE, curlVerbose);
        
        // #ifdef SKIP_PEER_VERIFICATION
        curl_easy_setopt(handle, CURLOPT_SSL_VERIFYPEER, 0L);
        
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
    // 
    HTTPClient client = new HTTPClient()
        .setBaseUrl("https://jsonplaceholder.typicode.com")
        .setUserAgent("Test/0.0.0");
    
    HTTPResponse res = client.get("/todos/1");
    // {
    //   "userId": 1,
    //   "id": 1,
    //   "title": "delectus aut autem",
    //   "completed": false
    // }
    writeln("test1: ", res.text);
    
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
}