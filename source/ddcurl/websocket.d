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

// NOTE: WebSocket struct allows to make multiple connections using a single WSClient

private
enum // Bitflag for WebSocket
{
    WEBSOCKET_ACTIVE = 1,
}

version (Windows)
{
    // WSAPoll was added to druntime's winsock2 bindings recently;
    // older versions may not have it, so we define our own.
    private import core.sys.windows.winsock2 : SOCKET;
    private struct ws_pollfd { SOCKET fd; short events; short revents; }
    private enum short WS_POLLIN = 0x0300, WS_POLLOUT = 0x0010,
        WS_POLLERR = 0x0001, WS_POLLHUP = 0x0002, WS_POLLNVAL = 0x0004;
    pragma(lib, "ws2_32");
    private extern (Windows) int WSAPoll(ws_pollfd* fdArray, uint fds, int timeout) @nogc;
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
        curl_slist *headers = null,
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

        // Get the underlying socket fd for poll()
        sockfd = getSocket();
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
        case CURLE_OK: break;
        case CURLE_AGAIN:
            pollSocket(POLLIN);
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
            pollSocket(POLLOUT);
            goto Lsend;
        default:
            throw new CurlException(code);
        }
        return sendsize;
    }
    
    /// Set the poll timeout in milliseconds.
    /// Params: ms = Timeout in milliseconds. Default is 10 seconds.
    void setPollTimeout(int ms)
    {
        pollTimeout = ms;
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
    int sockfd = -1;
    int pollTimeout = 10_000;
    
    version (Windows)
    {
        alias pollfd  = ws_pollfd;
        alias POLLIN  = WS_POLLIN;
        alias POLLOUT = WS_POLLOUT;
        alias POLLERR = WS_POLLERR;
        alias POLLHUP = WS_POLLHUP;
        alias POLLNVAL = WS_POLLNVAL;
        alias syspoll = WSAPoll;
    }
    else
    {
        import core.sys.posix.poll : pollfd, poll, POLLIN, POLLOUT, POLLERR, POLLHUP, POLLNVAL;
        alias syspoll = poll;
    }
    
    // Get the underlying socket fd from curl via CURLINFO_ACTIVESOCKET
    int getSocket()
    {
        long sockfd;
        CURLcode code = curl_easy_getinfo(curl, CURLINFO_ACTIVESOCKET, &sockfd);
        if (code)
            throw new CurlException(code);
        if (sockfd == -1)
            throw new CurlException("No active socket");
        return cast(int)sockfd;
    }
    
    // Poll the socket until it is ready for the given events (POLLIN or POLLOUT).
    void pollSocket(short events)
    {
        pollfd pfd;
        pfd.fd = sockfd;
        pfd.events = events;

        int ret = syspoll(&pfd, 1, pollTimeout);
        if (ret < 0)
            throw new Exception(cast(string)fromStringz( strerror(errno) ));
        if (ret == 0)
            throw new CurlException("WebSocket poll timed out");
        if (pfd.revents & (POLLERR | POLLHUP | POLLNVAL))
            throw new CurlException("WebSocket poll error");
    }
}

/// Old alias for WebSocket.
alias WebSocketConnection = WebSocket;

/// High-level representation of a WebSocket client.
class WebSocketClient
{
    this()
    {
        curlLoad(); // Depends on libcurl
    }
    
    /// Add header to all future connections.
    typeof(this) addHeader(string name, string value)
    {
        headers[name] = value;
        return this;
    }
    
    /// Set peer verification option.
    typeof(this) setVerifyPeers(bool v)
    {
        curlVerifyPeers = cast(c_long)v;
        return this;
    }
    
    /// Set CURL's verbose flag.
    typeof(this) setVerbose(bool v)
    {
        curlVerbose = cast(c_long)v;
        return this;
    }
    
    /// Connect to a WebSocket.
    ///
    /// Protocols: ws://, wss://
    /// Returns: WebSocket connection.
    WebSocket connect(string url)
    {
        assert(url);

        // Dynamic binding loads ws functions optionally; they may be null
        version (DynamicBinding)
        {
            if (curl_ws_recv == null || curl_ws_send == null)
                throw new Exception("WebSockets are unavailable");
        }

        // Open connection
        CURL *curl = curl_easy_init();
        if (curl == null)
            throw new CurlException("curl_easy_init failed");

        curl_set_option(curl, CURLOPT_URL, url.toStringz());
        curl_set_option(curl, CURLOPT_CONNECT_ONLY, 2); // WS style
        curl_set_option(curl, CURLOPT_SSL_VERIFYPEER, curlVerifyPeers);
        curl_set_option(curl, CURLOPT_SSL_VERIFYHOST, curlVerifyPeers);
        curl_set_option(curl, CURLOPT_VERBOSE, curlVerbose);

        // Set headers
        curl_slist *curl_headers;
        if (headers.length)
        {
            foreach (key, value; headers)
            {
                char[256] buffer = void;
                char[] header = sformat(buffer, "%s: %s", key, value);
                
                curl_slist *temp = curl_slist_append(curl_headers, header.toStringz());
                if (temp == null)
                {
                    curl_slist_free_all(curl_headers);
                    throw new CurlException("curl_slist_append failed");
                }
                curl_headers = temp;
            }

            curl_set_option(curl, CURLOPT_HTTPHEADER, curl_headers);
        }

        // Perform HTTP call, curl manages the upgrade
        CURLcode code = curl_easy_perform(curl);
        if (code)
            throw new CurlException(code);

        return WebSocket(curl, curl_headers);
    }
    
private:
    c_long curlVerifyPeers = 1;
    c_long curlVerbose;

    string[string] headers;
}

version (none)
unittest
{
    static immutable string wsurl = "wss://echo.websocket.org"; // echos whatever sent
    WebSocketClient wsclient = new WebSocketClient();
    WebSocket ws = wsclient.connect(wsurl);
    
    writeln("ws init: ", cast(string)ws.receive());
    
    writeln("ws sending: ", "test hello");
    ws.send("test hello");
    
    Thread.sleep(1.seconds);
    
    writeln("ws receiving: ", cast(string)ws.receive());
    ws.close();
}
