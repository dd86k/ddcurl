/// Implements C bindings for libcurl.
module ddcurl.libcurl;

import std.string;
import ddloader;

//
// libcurl interface
//

version (Windows)
{
    private immutable string[] curlname = [
        "libcurl.dll"
    ];
}
else version (Posix)
{
    private immutable string[] curlname = [
        "libcurl.so.4.8.0",
        "libcurl.so.4.7.0",
        "libcurl.so",
    ];
}

struct CURL {}
struct curl_slist {}

alias CURLcode = int;
alias CURLoption = int;
alias curl_off_t = long;

struct curl_ws_frame
{
    int age;              /// zero
    int flags;            /// See the CURLWS_* defines
    curl_off_t offset;    /// the offset of this data into the frame
    curl_off_t bytesleft; /// number of pending bytes left of the payload
    size_t len;           /// size of the current data chunk
}

enum : CURLcode
{
    CURLE_OK = 0,
    CURLE_UNSUPPORTED_PROTOCOL,    /* 1 */
    CURLE_FAILED_INIT,             /* 2 */
    CURLE_URL_MALFORMAT,           /* 3 */
    CURLE_NOT_BUILT_IN,            /* 4 - [was obsoleted in August 2007 for
                                    7.17.0, reused in April 2011 for 7.21.5] */
    CURLE_COULDNT_RESOLVE_PROXY,   /* 5 */
    CURLE_COULDNT_RESOLVE_HOST,    /* 6 */
    CURLE_COULDNT_CONNECT,         /* 7 */
    CURLE_WEIRD_SERVER_REPLY,      /* 8 */
    CURLE_REMOTE_ACCESS_DENIED,    /* 9 a service was denied by the server
                                    due to lack of access - when login fails
                                    this is not returned. */
    CURLE_FTP_ACCEPT_FAILED,       /* 10 - [was obsoleted in April 2006 for
                                    7.15.4, reused in Dec 2011 for 7.24.0]*/
    CURLE_FTP_WEIRD_PASS_REPLY,    /* 11 */
    CURLE_FTP_ACCEPT_TIMEOUT,      /* 12 - timeout occurred accepting server
                                    [was obsoleted in August 2007 for 7.17.0,
                                    reused in Dec 2011 for 7.24.0]*/
    CURLE_FTP_WEIRD_PASV_REPLY,    /* 13 */
    CURLE_FTP_WEIRD_227_FORMAT,    /* 14 */
    CURLE_FTP_CANT_GET_HOST,       /* 15 */
    CURLE_HTTP2,                   /* 16 - A problem in the http2 framing layer.
                                    [was obsoleted in August 2007 for 7.17.0,
                                    reused in July 2014 for 7.38.0] */
    CURLE_FTP_COULDNT_SET_TYPE,    /* 17 */
    CURLE_PARTIAL_FILE,            /* 18 */
    CURLE_FTP_COULDNT_RETR_FILE,   /* 19 */
    CURLE_OBSOLETE20,              /* 20 - NOT USED */
    CURLE_QUOTE_ERROR,             /* 21 - quote command failure */
    CURLE_HTTP_RETURNED_ERROR,     /* 22 */
    CURLE_WRITE_ERROR,             /* 23 */
    CURLE_OBSOLETE24,              /* 24 - NOT USED */
    CURLE_UPLOAD_FAILED,           /* 25 - failed upload "command" */
    CURLE_READ_ERROR,              /* 26 - could not open/read from file */
    CURLE_OUT_OF_MEMORY,           /* 27 */
    CURLE_OPERATION_TIMEDOUT,      /* 28 - the timeout time was reached */
    CURLE_OBSOLETE29,              /* 29 - NOT USED */
    CURLE_FTP_PORT_FAILED,         /* 30 - FTP PORT operation failed */
    CURLE_FTP_COULDNT_USE_REST,    /* 31 - the REST command failed */
    CURLE_OBSOLETE32,              /* 32 - NOT USED */
    CURLE_RANGE_ERROR,             /* 33 - RANGE "command" did not work */
    CURLE_HTTP_POST_ERROR,         /* 34 */
    CURLE_SSL_CONNECT_ERROR,       /* 35 - wrong when connecting with SSL */
    CURLE_BAD_DOWNLOAD_RESUME,     /* 36 - could not resume download */
    CURLE_FILE_COULDNT_READ_FILE,  /* 37 */
    CURLE_LDAP_CANNOT_BIND,        /* 38 */
    CURLE_LDAP_SEARCH_FAILED,      /* 39 */
    CURLE_OBSOLETE40,              /* 40 - NOT USED */
    CURLE_FUNCTION_NOT_FOUND,      /* 41 - NOT USED starting with 7.53.0 */
    CURLE_ABORTED_BY_CALLBACK,     /* 42 */
    CURLE_BAD_FUNCTION_ARGUMENT,   /* 43 */
    CURLE_OBSOLETE44,              /* 44 - NOT USED */
    CURLE_INTERFACE_FAILED,        /* 45 - CURLOPT_INTERFACE failed */
    CURLE_OBSOLETE46,              /* 46 - NOT USED */
    CURLE_TOO_MANY_REDIRECTS,      /* 47 - catch endless re-direct loops */
    CURLE_UNKNOWN_OPTION,          /* 48 - User specified an unknown option */
    CURLE_SETOPT_OPTION_SYNTAX,    /* 49 - Malformed setopt option */
    CURLE_OBSOLETE50,              /* 50 - NOT USED */
    CURLE_OBSOLETE51,              /* 51 - NOT USED */
    CURLE_GOT_NOTHING,             /* 52 - when this is a specific error */
    CURLE_SSL_ENGINE_NOTFOUND,     /* 53 - SSL crypto engine not found */
    CURLE_SSL_ENGINE_SETFAILED,    /* 54 - can not set SSL crypto engine as
                                    default */
    CURLE_SEND_ERROR,              /* 55 - failed sending network data */
    CURLE_RECV_ERROR,              /* 56 - failure in receiving network data */
    CURLE_OBSOLETE57,              /* 57 - NOT IN USE */
    CURLE_SSL_CERTPROBLEM,         /* 58 - problem with the local certificate */
    CURLE_SSL_CIPHER,              /* 59 - could not use specified cipher */
    CURLE_PEER_FAILED_VERIFICATION, /* 60 - peer's certificate or fingerprint
                                        was not verified fine */
    CURLE_BAD_CONTENT_ENCODING,    /* 61 - Unrecognized/bad encoding */
    CURLE_OBSOLETE62,              /* 62 - NOT IN USE since 7.82.0 */
    CURLE_FILESIZE_EXCEEDED,       /* 63 - Maximum file size exceeded */
    CURLE_USE_SSL_FAILED,          /* 64 - Requested FTP SSL level failed */
    CURLE_SEND_FAIL_REWIND,        /* 65 - Sending the data requires a rewind
                                    that failed */
    CURLE_SSL_ENGINE_INITFAILED,   /* 66 - failed to initialise ENGINE */
    CURLE_LOGIN_DENIED,            /* 67 - user, password or similar was not
                                    accepted and we failed to login */
    CURLE_TFTP_NOTFOUND,           /* 68 - file not found on server */
    CURLE_TFTP_PERM,               /* 69 - permission problem on server */
    CURLE_REMOTE_DISK_FULL,        /* 70 - out of disk space on server */
    CURLE_TFTP_ILLEGAL,            /* 71 - Illegal TFTP operation */
    CURLE_TFTP_UNKNOWNID,          /* 72 - Unknown transfer ID */
    CURLE_REMOTE_FILE_EXISTS,      /* 73 - File already exists */
    CURLE_TFTP_NOSUCHUSER,         /* 74 - No such user */
    CURLE_OBSOLETE75,              /* 75 - NOT IN USE since 7.82.0 */
    CURLE_OBSOLETE76,              /* 76 - NOT IN USE since 7.82.0 */
    CURLE_SSL_CACERT_BADFILE,      /* 77 - could not load CACERT file, missing
                                    or wrong format */
    CURLE_REMOTE_FILE_NOT_FOUND,   /* 78 - remote file not found */
    CURLE_SSH,                     /* 79 - error from the SSH layer, somewhat
                                    generic so the error message will be of
                                    interest when this has happened */

    CURLE_SSL_SHUTDOWN_FAILED,     /* 80 - Failed to shut down the SSL
                                    connection */
    CURLE_AGAIN,                   /* 81 - socket is not ready for send/recv,
                                    wait till it is ready and try again (Added
                                    in 7.18.2) */
    CURLE_SSL_CRL_BADFILE,         /* 82 - could not load CRL file, missing or
                                    wrong format (Added in 7.19.0) */
    CURLE_SSL_ISSUER_ERROR,        /* 83 - Issuer check failed.  (Added in
                                    7.19.0) */
    CURLE_FTP_PRET_FAILED,         /* 84 - a PRET command failed */
    CURLE_RTSP_CSEQ_ERROR,         /* 85 - mismatch of RTSP CSeq numbers */
    CURLE_RTSP_SESSION_ERROR,      /* 86 - mismatch of RTSP Session Ids */
    CURLE_FTP_BAD_FILE_LIST,       /* 87 - unable to parse FTP file list */
    CURLE_CHUNK_FAILED,            /* 88 - chunk callback reported error */
    CURLE_NO_CONNECTION_AVAILABLE, /* 89 - No connection available, the
                                    session will be queued */
    CURLE_SSL_PINNEDPUBKEYNOTMATCH, /* 90 - specified pinned public key did not
                                        match */
    CURLE_SSL_INVALIDCERTSTATUS,   /* 91 - invalid certificate status */
    CURLE_HTTP2_STREAM,            /* 92 - stream error in HTTP/2 framing layer
                                    */
    CURLE_RECURSIVE_API_CALL,      /* 93 - an api function was called from
                                    inside a callback */
    CURLE_AUTH_ERROR,              /* 94 - an authentication function returned an
                                    error */
    CURLE_HTTP3,                   /* 95 - An HTTP/3 layer problem */
    CURLE_QUIC_CONNECT_ERROR,      /* 96 - QUIC connection error */
    CURLE_PROXY,                   /* 97 - proxy handshake error */
    CURLE_SSL_CLIENTCERT,          /* 98 - client-side certificate required */
    CURLE_UNRECOVERABLE_POLL,      /* 99 - poll/select returned fatal error */
    CURLE_TOO_LARGE,               /* 100 - a value/data met its maximum */
    CURLE_ECH_REQUIRED,            /* 101 - ECH tried but failed */
    CURL_LAST /* never use! */
}

enum
{
    CURLOPTTYPE_LONG            = 0,
    CURLOPTTYPE_OBJECTPOINT     = 10000,
    CURLOPTTYPE_FUNCTIONPOINT   = 20000,
    CURLOPTTYPE_OFF_T           = 30000,
    CURLOPTTYPE_BLOB            = 40000,

    // Aliases
    CURLOPTTYPE_STRINGPOINT     = CURLOPTTYPE_OBJECTPOINT,
    CURLOPTTYPE_SLISTPOINT      = CURLOPTTYPE_OBJECTPOINT,
    CURLOPTTYPE_CBPOINT         = CURLOPTTYPE_OBJECTPOINT,
    CURLOPTTYPE_VALUES          = CURLOPTTYPE_LONG,
}

// #define CURLOPT(na,t,nu) na = t + nu
template CURLOPT(int t, int nu) { enum CURLOPT = t + nu; }

enum
{
    CURLOPT_WRITEDATA       = CURLOPT!(CURLOPTTYPE_CBPOINT, 1),
    CURLOPT_URL             = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 2),
    CURLOPT_ERRORBUFFER     = CURLOPT!(CURLOPTTYPE_OBJECTPOINT, 10),
    CURLOPT_WRITEFUNCTION   = CURLOPT!(CURLOPTTYPE_FUNCTIONPOINT, 11),
    CURLOPT_POSTFIELDS      = CURLOPT!(CURLOPTTYPE_OBJECTPOINT, 15),
    CURLOPT_USERAGENT       = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 18),
    CURLOPT_HTTPHEADER      = CURLOPT!(CURLOPTTYPE_SLISTPOINT, 23),
    CURLOPT_VERBOSE         = CURLOPT!(CURLOPTTYPE_LONG, 41),
    CURLOPT_NOPROGRESS      = CURLOPT!(CURLOPTTYPE_LONG, 43),
    CURLOPT_POST            = CURLOPT!(CURLOPTTYPE_LONG, 47),
    CURLOPT_POSTFIELDSIZE   = CURLOPT!(CURLOPTTYPE_LONG, 60),
    CURLOPT_SSL_VERIFYPEER  = CURLOPT!(CURLOPTTYPE_LONG, 64),
    CURLOPT_MAXREDIRS       = CURLOPT!(CURLOPTTYPE_LONG, 68),
    CURLOPT_CONNECT_ONLY    = CURLOPT!(CURLOPTTYPE_LONG, 141),
    CURLOPT_TCP_KEEPALIVE   = CURLOPT!(CURLOPTTYPE_LONG, 213),
}

alias CURLINFO = int;

enum
{
    CURLINFO_STRING   = 0x100000,
    CURLINFO_LONG     = 0x200000,
    CURLINFO_DOUBLE   = 0x300000,
    CURLINFO_SLIST    = 0x400000,
    CURLINFO_PTR      = 0x400000, /* same as SLIST */
    CURLINFO_SOCKET   = 0x500000,
    CURLINFO_OFF_T    = 0x600000,
    CURLINFO_MASK     = 0x0fffff,
    CURLINFO_TYPEMASK = 0xf00000,
}

enum
{
    CURLINFO_RESPONSE_CODE    = CURLINFO_LONG   + 2,
}

enum CURL_GLOBAL_SSL        = (1<<0); /* no purpose since 7.57.0 */
enum CURL_GLOBAL_WIN32      = (1<<1);
enum CURL_GLOBAL_ALL        = (CURL_GLOBAL_SSL|CURL_GLOBAL_WIN32);
enum CURL_GLOBAL_NOTHING    = 0;
enum CURL_GLOBAL_DEFAULT    = CURL_GLOBAL_ALL;

enum CURL_ERROR_SIZE        = 256;

enum
{
    CURLWS_TEXT       = 1 << 0,
    CURLWS_BINARY     = 1 << 1,
    CURLWS_CONT       = 1 << 2,
    CURLWS_CLOSE      = 1 << 3,
    CURLWS_PING       = 1 << 4,
    CURLWS_OFFSET     = 1 << 5,
    CURLWS_PONG       = 1 << 6,
}

private __gshared
{
    DynamicLibrary libcurl;
}

__gshared extern (C)
{
    // char *curl_version();
    const(char)* function() curl_version;
    // 
    //const(char)* function(CURL*) curl_error;
    // const char *curl_easy_strerror(CURLcode);
    const(char)* function(CURLcode) curl_easy_strerror;
    
    // CURLcode curl_global_init(long flags);
    CURLcode function(long flags) curl_global_init;
    
    // struct curl_slist *curl_slist_append(struct curl_slist *list, const char *string);
    curl_slist* function(curl_slist *list, const(char) *string_) curl_slist_append;
    // void curl_slist_free_all(struct curl_slist *list);
    void function(curl_slist *list) curl_slist_free_all;
    
    // CURL *curl_easy_init();
    CURL* function() curl_easy_init;
    // CURL *curl_easy_duphandle(CURL *handle);
    CURL* function(CURL *handle) curl_easy_duphandle;
    // CURLcode curl_easy_setopt(CURL *handle, CURLoption option, parameter);
    CURLcode function(CURL *handle, CURLoption option, ...) curl_easy_setopt;
    // CURLcode curl_easy_perform(CURL *easy_handle);
    CURLcode function(CURL *easy_handle) curl_easy_perform;
    // void curl_easy_cleanup(CURL *handle);
    void function(CURL *handle) curl_easy_cleanup;
    // CURLcode curl_easy_getinfo(CURL *curl, CURLINFO info, ...);
    CURLcode function(CURL *curl, CURLINFO info, ...) curl_easy_getinfo;
    
    // CURLcode curl_ws_recv(CURL *curl, void *buffer, size_t buflen,
    //                       size_t *recv,
    //                       const struct curl_ws_frame **metap);
    CURLcode function(CURL *curl,
        void *buffer, size_t buflen,
        size_t *recv, curl_ws_frame **metap) curl_ws_recv;
    
    // CURLcode curl_ws_send(CURL *curl, const void *buffer,
    //                       size_t buflen, size_t *sent,
    //                       curl_off_t fragsize,
    //                       unsigned int flags);
    CURLcode function(CURL *curl, const void *buffer,
        size_t buflen, size_t *sent,
        curl_off_t fragsize,
        uint flags) curl_ws_send;
}

void curlLoad()
{
    if (libcurl.handle) return;
    
    libcurl = libraryLoad(curlname);
    libraryBind(libcurl, cast(void**)&curl_version,    "curl_version");
    
    libraryBind(libcurl, cast(void**)&curl_global_init,    "curl_global_init");
    
    libraryBind(libcurl, cast(void**)&curl_slist_append,   "curl_slist_append");
    libraryBind(libcurl, cast(void**)&curl_slist_free_all, "curl_slist_free_all");
    
    libraryBind(libcurl, cast(void**)&curl_easy_cleanup,   "curl_easy_cleanup");
    libraryBind(libcurl, cast(void**)&curl_easy_duphandle, "curl_easy_duphandle");
    libraryBind(libcurl, cast(void**)&curl_easy_getinfo,   "curl_easy_getinfo");
    libraryBind(libcurl, cast(void**)&curl_easy_init,      "curl_easy_init");
    libraryBind(libcurl, cast(void**)&curl_easy_perform,   "curl_easy_perform");
    libraryBind(libcurl, cast(void**)&curl_easy_setopt,    "curl_easy_setopt");
    libraryBind(libcurl, cast(void**)&curl_easy_strerror,  "curl_easy_strerror");
    
    try // optional
    {
        libraryBind(libcurl, cast(void**)&curl_ws_recv,    "curl_ws_recv");
        libraryBind(libcurl, cast(void**)&curl_ws_send,    "curl_ws_send");
    }
    catch (Exception)
    {
    }
    
    curl_global_init(CURL_GLOBAL_DEFAULT);
}

string curlErrorMessage(CURLcode code)
{
    return cast(string)fromStringz( curl_easy_strerror(code) );
}

string curlVersion()
{
    curlLoad();
    
    // "libcurl/VERSION other/VERSION" etc.
    string verstring = cast(string)fromStringz( curl_version() );
    
    // if ' ' is found in string after first position
    ptrdiff_t firstspace = indexOf(verstring, ' ');
    if (firstspace <= 0)
        return verstring;
    
    // if '/' is found in string after first position
    verstring = verstring[0..firstspace];
    ptrdiff_t firstslash = indexOf(verstring, '/');
    if (firstspace <= 0 || firstslash + 1 >= verstring.length)
        return verstring;
    
    return verstring[firstslash+1..$]; // Return only version number
}