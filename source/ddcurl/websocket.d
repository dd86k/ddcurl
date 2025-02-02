/// High-level implementation of a WebSocket using libcurl.
module ddcurl.websocket;

import core.stdc.stdlib : malloc, realloc, free;
import core.stdc.string : memcpy, strerror;
import core.stdc.errno  : errno;
import core.thread;
import std.format;
import std.string;
import std.json;
import ddcurl.libcurl;
import ddlogger;

/// Represents an active WebSocket connection.
struct WebSocketConnection
{
    this(CURL *handle, size_t bufferSize = 16 * 1024)
    {
        curl = handle;
        buffer = malloc(bufferSize);
        if (buffer == null)
            throw new Exception(cast(string)fromStringz( strerror(errno) ));
        bufsize = bufferSize;
    }
    
    ubyte[] receive()
    {
        size_t total;
        size_t rdsize = void;
    Lread:
        size_t bufleft = bufsize - total;
        CURLcode code = curl_ws_recv(curl, buffer + total, bufleft, &rdsize, &curl_frame);
        if (curl_frame)
        {
            with (curl_frame)
            logTrace("curl_ws_recv: code=%d curl_ws_frame { age=%d flags=%x offset=%d left=%d len=%u }",
                code, age, flags, offset, bytesleft, len);
            
            if (curl_frame.flags & CURLWS_CLOSE)
                return null;
        }
        
        if (code)
        {
            switch (code) {
            case CURLE_AGAIN:
                static immutable Duration ws_sleep = 5.seconds;
                logTrace("Socket not ready, sleeping for %s", ws_sleep);
                Thread.sleep(ws_sleep);
                goto Lread;
            default:
            }
            throw new Exception(curlErrorMessage(code));
        }
        
        total += rdsize;
        logTrace("Frame: %u / %u bytes", total, bufsize);
        
        // Incomplete frame
        if (curl_frame.bytesleft > 0)
        {
            if (total + curl_frame.bytesleft >= bufsize)
            {
                size_t newsize = total + curl_frame.bytesleft;
                buffer = realloc(buffer, newsize);
                if (buffer == null)
                    throw new Exception("realloc failed");
                bufsize = newsize;
            }
            
            goto Lread;
        }
        
        return cast(ubyte[])buffer[0..total];
    }
    
    size_t send(const(char)[] data)
    {
        return curl_send(cast(ubyte[])data, CURLWS_TEXT);
    }
    
    size_t send(ubyte[] data)
    {
        return curl_send(data, CURLWS_BINARY);
    }
    
    void close()
    {
        size_t sent = void;
        cast(void)curl_ws_send(curl, "".ptr, 0, &sent, 0, CURLWS_CLOSE);
    }
    
private:
    CURL *curl;
    curl_ws_frame *curl_frame;
    
    void *buffer;
    size_t bufsize;
    
    size_t curl_send(ubyte[] data, int flags)
    {
        // TODO: Check if curl_ws_send returns CURLE_AGAIN
        //       If so, the thread sleeps in implementations can be avoided
        size_t sendsize;
        CURLcode code = curl_ws_send(curl, data.ptr, data.length, &sendsize, 0, flags);
        if (code)
            throw new Exception(curlErrorMessage(code));
        return sendsize;
    }
}

/// High-level representation of a WebSocket client.
class WebSocketClient
{
    this()
    {
        curlLoad(); // Depends on libcurl
    }
    
    // add default header to requests
    typeof(this) addHeader(string name, string value)
    {
        headers[name] = value;
        return this;
    }
    
    // ws://, wss://
    void connect(string url, void delegate(ref WebSocketConnection) dg)
    {
        assert(url);
        assert(dg);
        
        // Open connection
        curl = curl_easy_init();
        if (curl == null)
            throw new Exception("curl_easy_init failed");
        
        curl_easy_setopt(curl, CURLOPT_URL, toStringz( url ));
        curl_easy_setopt(curl, CURLOPT_CONNECT_ONLY, 2L); // WS style
        curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
        //curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);
        
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
            
            curl_easy_setopt(curl, CURLOPT_HTTPHEADER, slist_headers);
        }
        
        CURLcode code = curl_easy_perform(curl);
        if (code)
            throw new Exception(curlErrorMessage(code));
        
        WebSocketConnection ws = WebSocketConnection(curl);
        dg(ws);
        
        curl_easy_cleanup(curl);
    }
    
private:
    CURL *curl;

    string[string] headers;
}

version (none)
unittest
{
    static immutable string wsurl = "wss://echo.websocket.org"; // echos whatever sent
    WebSocketClient wsclient = new WebSocketClient();
    wsclient.connect(wsurl, (ref WebSocketConnection ws) {
        writeln("ws init: ", cast(string)ws.receive());
        
        writeln("ws sending: ", "test hello");
        ws.send("test hello");
        
        Thread.sleep(1.seconds);
        
        writeln("ws receiving: ", cast(string)ws.receive());
    });
}
