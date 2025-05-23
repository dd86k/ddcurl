/// High-level implementation of a WebSocket using libcurl.
module ddcurl.websocket;

import core.stdc.stdlib : malloc, realloc, free;
import core.stdc.string : memcpy, strerror;
import core.stdc.errno  : errno;
import core.stdc.config : c_long;
import std.format;
import std.string;
import ddcurl.libcurl;
import ddlogger;

private
enum // Bitflag for WebSocket
{
    WEBSOCKET_ACTIVE = 1,
}

/// Represents an active WebSocket connection.
struct WebSocket
{
    /// Invoke constructor with an active CURL pointer instance.
    ///
    /// Usually, HTTPClient should have created one for you using HTTPClient.connectSocket,
    /// but in the case that HTTPClient doesn't cover a use-case, you're free to initiate
    /// a WebSocket instance here.
    this(CURL *handle,
        curl_slist *headers = null, // compat with older WebSocketClient class
        size_t bufferSize = 4 * 1024)
    {
        // Allocate buffer for receiving data
        buffer = malloc(bufferSize);
        if (buffer == null)
            throw new Exception(cast(string)fromStringz( strerror(errno) ));
        bufsize = bufferSize;
        
        curl = handle;
        curl_headers = headers;
        status = WEBSOCKET_ACTIVE;
    }
    
    ~this()
    {
        close();
    }
    
    /// Receive data.
    /// Returns: Buffer. If empty (null), then connection was closed.
    ubyte[] receive()
    {
        assert(curl,    "curl==null");
        assert(buffer,  "buffer==null");
        assert(bufsize, "bufsize==0");
        
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
            
            // Closing
            if (curl_frame.flags & CURLWS_CLOSE)
            {
                close();
                return null;
            }
        }
        
        switch (code) {
        case CURLE_OK:
        case CURLE_AGAIN:
            // HACK: Sleep instead, until things synchronizes, or whatever
            //       See HACK with the sleeptime variable
            logTrace("Socket not ready, sleeping for %s", sleeptime);
            Thread.sleep(sleeptime);
            goto Lread;
        default:
            throw new CurlException(code);
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
                    throw new CurlException("realloc failed");
                bufsize = newsize;
            }
            
            goto Lread;
        }
        
        return cast(ubyte[])buffer[0..total];
    }
    
    /// Send text data (CURLWS_TEXT).
    /// Params: data = Text buffer.
    /// Returns: Number of sent bytes.
    size_t send(const(char)[] data)
    {
        return send(cast(ubyte[])data, CURLWS_TEXT);
    }
    
    /// Send binary data (CURLWS_BINARY).
    /// Params: data = Byte buffer.
    /// Returns: Number of sent bytes.
    size_t send(ubyte[] data)
    {
        return send(data, CURLWS_BINARY);
    }
    
    /// Send data.
    ///
    /// Note that flags contain either CURLWS_TEXT, CURLWS_BINARY,
    /// CURLWS_CLOSE, CURLWS_PING, or CURLWS_PONG.
    /// Params:
    ///   data = Byte buffer.
    ///   flags = Flags to curl_ws_send.
    /// Returns: Number of sent bytes.
    size_t send(ubyte[] data, int flags)
    {
        size_t sendsize;
    Lsend:
        CURLcode code = curl_ws_send(curl, data.ptr, data.length, &sendsize, 0, flags);
        switch (code) {
        case CURLE_OK: break;
        case CURLE_AGAIN:
            // HACK: Sleep instead, until things synchronizes, or whatever
            //       See HACK with the sleeptime variable
            Thread.sleep(sleeptime);
            goto Lsend;
        default:
            throw new CurlException(code);
        }
        return sendsize;
    }
    
    /// Close the WebSocket connection.
    ///
    /// This sends CURLWS_CLOSE and frees up the buffers
    void close()
    {
        status = 0;
        
        // Send close notification
        size_t sent = void;
        // The example uses "" instead of null, best avoid trouble.
        // Avoid using the CURLcode being returned, we're closing shop, anyway.
        cast(void)curl_ws_send(curl, "".ptr, 0, &sent, 0, CURLWS_CLOSE);
        
        // Free buffer
        if (buffer) free(buffer);
        buffer  = null;
        bufsize = 0;
        
        // Cleanup headers
        if (curl_headers)
            curl_slist_free_all(curl_headers);
        
        // Cleanup
        if (curl)
            curl_easy_cleanup(curl);
        curl = null;
    }
    
    /// Check if connection is still active.
    /// Returns: true if connection active
    bool active()
    {
        return status > 0;
    }
    
private:
    CURL *curl;
    curl_slist *curl_headers;
    curl_ws_frame *curl_frame;
    
    void *buffer;
    size_t bufsize;
    int status;
    
    // HACK: When CURLE_AGAIN happens, because we don't have easy access to select(3),
    //       we temporarily sleep the thread, to let the socket do its things.
    // TODO: Use select(3) as noted from example.
    //       But that's not generally available easily, at least from D.
    //       And curl does not provide a function to do that easily, cool!
    //       There are the receive and send situations in here.
    import core.thread : Thread, dur, Duration;
    static immutable Duration sleeptime = dur!"msecs"(100);
}

/// Old alias for WebSocket.
alias WebSocketConnection = WebSocket;

/// High-level representation of a WebSocket client.
deprecated("Use HTTPClient.websocket")
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
    
    typeof(this) setVerifyPeers(bool v)
    {
        curlVerifyPeers = cast(long)v;
        return this;
    }
    
    typeof(this) setVerbose(bool v)
    {
        curlVerbose = cast(long)v;
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
            throw new CurlException("curl_easy_init failed");
        
        curl_set_option(curl, CURLOPT_URL, url.toStringz());
        curl_set_option(curl, CURLOPT_CONNECT_ONLY, 2); // WS style
        curl_set_option(curl, CURLOPT_SSL_VERIFYPEER, curlVerifyPeers);
        curl_set_option(curl, CURLOPT_SSL_VERIFYHOST, curlVerifyPeers);
        curl_set_option(curl, CURLOPT_VERBOSE, curlVerbose);
        
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
                    throw new CurlException("curl_slist_append failed");
            }
            
            curl_set_option(curl, CURLOPT_HTTPHEADER, slist_headers);
        }
        
        // Perform HTTP call with upgrade
        CURLcode code = curl_easy_perform(curl);
        if (code)
            throw new CurlException(code);
        
        // Call user delegate
        WebSocketConnection ws = WebSocketConnection(curl);
        dg(ws);
        
        // If we had headers, clear them
        if (slist_headers)
            curl_slist_free_all(slist_headers);
        
        curl_easy_cleanup(curl);
    }
    
private:
    CURL *curl;
    c_long curlVerifyPeers = 1;
    c_long curlVerbose;

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
