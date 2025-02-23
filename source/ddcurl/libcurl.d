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

alias curl_off_t = long;

struct curl_ws_frame
{
    int age;              /// zero
    int flags;            /// See the CURLWS_* defines
    curl_off_t offset;    /// the offset of this data into the frame
    curl_off_t bytesleft; /// number of pending bytes left of the payload
    size_t len;           /// size of the current data chunk
}

alias CURLcode = int;
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

private enum
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

// TODO: alias #define CURLOPT_PROGRESSDATA CURLOPT_XFERINFODATA
alias CURLoption = int;
enum : CURLoption
{
    CURLOPT_WRITEDATA           = CURLOPT!(CURLOPTTYPE_CBPOINT, 1),
    CURLOPT_URL                 = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 2),
    CURLOPT_PORT                = CURLOPT!(CURLOPTTYPE_LONG, 3),
    CURLOPT_PROXY               = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 4),
    CURLOPT_USERPWD             = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 5),
    CURLOPT_PROXYUSERPWD        = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 6),
    CURLOPT_RANGE               = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 7),
    CURLOPT_READDATA            = CURLOPT!(CURLOPTTYPE_CBPOINT, 9),
    CURLOPT_ERRORBUFFER         = CURLOPT!(CURLOPTTYPE_OBJECTPOINT, 10),
    CURLOPT_WRITEFUNCTION       = CURLOPT!(CURLOPTTYPE_FUNCTIONPOINT, 11),
    CURLOPT_READFUNCTION        = CURLOPT!(CURLOPTTYPE_FUNCTIONPOINT, 12),
    CURLOPT_TIMEOUT             = CURLOPT!(CURLOPTTYPE_LONG, 13),
    CURLOPT_POSTFIELDS          = CURLOPT!(CURLOPTTYPE_OBJECTPOINT, 15),
    CURLOPT_USERAGENT           = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 18),
    CURLOPT_REFERER             = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 16),
    CURLOPT_FTPPORT             = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 17),
    CURLOPT_LOW_SPEED_TIME      = CURLOPT!(CURLOPTTYPE_LONG, 20),
    CURLOPT_COOKIE              = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 22),
    CURLOPT_HTTPHEADER          = CURLOPT!(CURLOPTTYPE_SLISTPOINT, 23),
    CURLOPT_KEYPASSWD           = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 26),
    CURLOPT_CRLF                = CURLOPT!(CURLOPTTYPE_LONG, 27),
    CURLOPT_QUOTE               = CURLOPT!(CURLOPTTYPE_SLISTPOINT, 28),
    CURLOPT_HEADERDATA          = CURLOPT!(CURLOPTTYPE_CBPOINT, 29),
    CURLOPT_COOKIEFILE          = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 31),
    CURLOPT_SSLVERSION          = CURLOPT!(CURLOPTTYPE_VALUES, 32),
    CURLOPT_TIMECONDITION       = CURLOPT!(CURLOPTTYPE_VALUES, 33),
    CURLOPT_TIMEVALUE           = CURLOPT!(CURLOPTTYPE_LONG, 34),
    CURLOPT_CUSTOMREQUEST       = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 36),
    CURLOPT_STDERR              = CURLOPT!(CURLOPTTYPE_OBJECTPOINT, 37),
    CURLOPT_POSTQUOTE           = CURLOPT!(CURLOPTTYPE_SLISTPOINT, 39),
    CURLOPT_VERBOSE             = CURLOPT!(CURLOPTTYPE_LONG, 41),
    CURLOPT_HEADER              = CURLOPT!(CURLOPTTYPE_LONG, 42),
    CURLOPT_NOBODY              = CURLOPT!(CURLOPTTYPE_LONG, 44),
    CURLOPT_NOPROGRESS          = CURLOPT!(CURLOPTTYPE_LONG, 43),
    CURLOPT_FAILONERROR         = CURLOPT!(CURLOPTTYPE_LONG, 45),
    CURLOPT_UPLOAD              = CURLOPT!(CURLOPTTYPE_LONG, 46),
    CURLOPT_POST                = CURLOPT!(CURLOPTTYPE_LONG, 47),
    CURLOPT_DIRLISTONLY         = CURLOPT!(CURLOPTTYPE_LONG, 48),
    CURLOPT_APPEND              = CURLOPT!(CURLOPTTYPE_LONG, 50),
    CURLOPT_NETRC               = CURLOPT!(CURLOPTTYPE_VALUES, 51),
    CURLOPT_FOLLOWLOCATION      = CURLOPT!(CURLOPTTYPE_LONG, 52),
    CURLOPT_TRANSFERTEXT        = CURLOPT!(CURLOPTTYPE_LONG, 53),
    CURLOPT_XFERINFODATA        = CURLOPT!(CURLOPTTYPE_CBPOINT, 57),
    CURLOPT_PROGRESSDATA        = CURLOPT_XFERINFODATA, // alias
    CURLOPT_AUTOREFERER         = CURLOPT!(CURLOPTTYPE_LONG, 58),
    CURLOPT_PROXYPORT           = CURLOPT!(CURLOPTTYPE_LONG, 59),
    CURLOPT_POSTFIELDSIZE       = CURLOPT!(CURLOPTTYPE_LONG, 60),
    CURLOPT_HTTPPROXYTUNNEL     = CURLOPT!(CURLOPTTYPE_LONG, 61),
    CURLOPT_INTERFACE           = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 62),
    CURLOPT_CAINFO              = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 65),
    CURLOPT_SSL_VERIFYPEER      = CURLOPT!(CURLOPTTYPE_LONG, 64),
    CURLOPT_MAXREDIRS           = CURLOPT!(CURLOPTTYPE_LONG, 68),
    CURLOPT_FILETIME            = CURLOPT!(CURLOPTTYPE_LONG, 69),
    CURLOPT_TELNETOPTIONS       = CURLOPT!(CURLOPTTYPE_SLISTPOINT, 70),
    CURLOPT_MAXCONNECTS         = CURLOPT!(CURLOPTTYPE_LONG, 71),
    CURLOPT_FRESH_CONNECT       = CURLOPT!(CURLOPTTYPE_LONG, 74),
    CURLOPT_HEADERFUNCTION      = CURLOPT!(CURLOPTTYPE_FUNCTIONPOINT, 79),
    CURLOPT_COOKIEJAR           = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 82),
    CURLOPT_SSL_CIPHER_LIST     = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 83),
    CURLOPT_HTTP_VERSION        = CURLOPT!(CURLOPTTYPE_VALUES, 84),
    CURLOPT_SSLCERTTYPE         = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 86),
    CURLOPT_SSLKEY              = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 87),
    CURLOPT_SSLKEYTYPE          = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 88),
    CURLOPT_SSLENGINE           = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 89),
    CURLOPT_PREQUOTE            = CURLOPT!(CURLOPTTYPE_SLISTPOINT, 93),
    CURLOPT_DEBUGFUNCTION       = CURLOPT!(CURLOPTTYPE_FUNCTIONPOINT, 94),
    CURLOPT_DEBUGDATA           = CURLOPT!(CURLOPTTYPE_CBPOINT, 95),
    CURLOPT_COOKIESESSION       = CURLOPT!(CURLOPTTYPE_LONG, 96),
    CURLOPT_CAPATH              = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 97),
    CURLOPT_BUFFERSIZE          = CURLOPT!(CURLOPTTYPE_LONG, 98),
    CURLOPT_SHARE               = CURLOPT!(CURLOPTTYPE_OBJECTPOINT, 100),
    CURLOPT_PRIVATE             = CURLOPT!(CURLOPTTYPE_OBJECTPOINT, 103),
    CURLOPT_HTTP200ALIASES      = CURLOPT!(CURLOPTTYPE_SLISTPOINT, 104),
    CURLOPT_SSL_CTX_DATA        = CURLOPT!(CURLOPTTYPE_CBPOINT, 109),
    CURLOPT_POSTFIELDSIZE_LARGE = CURLOPT!(CURLOPTTYPE_OFF_T, 120),
    CURLOPT_TCP_NODELAY         = CURLOPT!(CURLOPTTYPE_LONG, 121),
    CURLOPT_FTP_ACCOUNT         = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 134),
    CURLOPT_COOKIELIST          = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 135),
    CURLOPT_IGNORE_CONTENT_LENGTH   = CURLOPT!(CURLOPTTYPE_LONG, 136),
    CURLOPT_FTP_FILEMETHOD      = CURLOPT!(CURLOPTTYPE_VALUES, 138),
    CURLOPT_LOCALPORT           = CURLOPT!(CURLOPTTYPE_LONG, 139),
    CURLOPT_CONNECT_ONLY        = CURLOPT!(CURLOPTTYPE_LONG, 141),
    CURLOPT_MAX_SEND_SPEED_LARGE    = CURLOPT!(CURLOPTTYPE_OFF_T, 145),
    CURLOPT_FTP_ALTERNATIVE_TO_USER = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 147),
    CURLOPT_SOCKOPTFUNCTION     = CURLOPT!(CURLOPTTYPE_FUNCTIONPOINT, 148),
    CURLOPT_SSL_SESSIONID_CACHE = CURLOPT!(CURLOPTTYPE_LONG, 150),
    CURLOPT_SSH_AUTH_TYPES      = CURLOPT!(CURLOPTTYPE_VALUES, 151),
    CURLOPT_SSH_PUBLIC_KEYFILE  = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 152),
    CURLOPT_FTP_SSL_CCC         = CURLOPT!(CURLOPTTYPE_LONG, 154),
    CURLOPT_TIMEOUT_MS          = CURLOPT!(CURLOPTTYPE_LONG, 155),
    CURLOPT_HTTP_TRANSFER_DECODING  = CURLOPT!(CURLOPTTYPE_LONG, 157),
    CURLOPT_NEW_FILE_PERMS      = CURLOPT!(CURLOPTTYPE_LONG, 159),
    CURLOPT_POSTREDIR           = CURLOPT!(CURLOPTTYPE_VALUES, 161),
    CURLOPT_SSH_HOST_PUBLIC_KEY_MD5 = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 162),
    CURLOPT_OPENSOCKETDATA      = CURLOPT!(CURLOPTTYPE_CBPOINT, 164),
    CURLOPT_COPYPOSTFIELDS      = CURLOPT!(CURLOPTTYPE_OBJECTPOINT, 165),
    CURLOPT_PROXY_TRANSFER_MODE = CURLOPT!(CURLOPTTYPE_LONG, 166),
    CURLOPT_SEEKFUNCTION        = CURLOPT!(CURLOPTTYPE_FUNCTIONPOINT, 167),
    CURLOPT_CRLFILE             = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 169),
    CURLOPT_ISSUERCERT          = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 170),
    CURLOPT_ADDRESS_SCOPE       = CURLOPT!(CURLOPTTYPE_LONG, 171),
    CURLOPT_CERTINFO            = CURLOPT!(CURLOPTTYPE_LONG, 172),
    CURLOPT_USERNAME            = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 173),
    CURLOPT_PROXYUSERNAME       = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 175),
    CURLOPT_TFTP_BLKSIZE        = CURLOPT!(CURLOPTTYPE_LONG, 178),
    CURLOPT_SSH_KNOWNHOSTS      = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 183),
    CURLOPT_SSH_KEYFUNCTION     = CURLOPT!(CURLOPTTYPE_FUNCTIONPOINT, 184),
    CURLOPT_SSH_KEYDATA         = CURLOPT!(CURLOPTTYPE_CBPOINT, 185),
    CURLOPT_MAIL_FROM           = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 186),
    CURLOPT_MAIL_RCPT           = CURLOPT!(CURLOPTTYPE_SLISTPOINT, 187),
    CURLOPT_FTP_USE_PRET        = CURLOPT!(CURLOPTTYPE_LONG, 188),
    CURLOPT_RTSP_REQUEST        = CURLOPT!(CURLOPTTYPE_VALUES, 189),
    CURLOPT_RTSP_SESSION_ID     = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 190),
    CURLOPT_RTSP_STREAM_URI     = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 191),
    CURLOPT_RTSP_TRANSPORT      = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 192),
    CURLOPT_RTSP_CLIENT_CSEQ    = CURLOPT!(CURLOPTTYPE_LONG, 193),
    CURLOPT_RTSP_SERVER_CSEQ    = CURLOPT!(CURLOPTTYPE_LONG, 194),
    CURLOPT_INTERLEAVEDATA      = CURLOPT!(CURLOPTTYPE_CBPOINT, 195),
    CURLOPT_INTERLEAVEFUNCTION  = CURLOPT!(CURLOPTTYPE_FUNCTIONPOINT, 196),
    CURLOPT_WILDCARDMATCH       = CURLOPT!(CURLOPTTYPE_LONG, 197),
    CURLOPT_CHUNK_BGN_FUNCTION  = CURLOPT!(CURLOPTTYPE_FUNCTIONPOINT, 198),
    CURLOPT_CHUNK_END_FUNCTION  = CURLOPT!(CURLOPTTYPE_FUNCTIONPOINT, 199),
    CURLOPT_FNMATCH_FUNCTION    = CURLOPT!(CURLOPTTYPE_FUNCTIONPOINT, 200),
    CURLOPT_CHUNK_DATA          = CURLOPT!(CURLOPTTYPE_CBPOINT, 201),
    CURLOPT_FNMATCH_DATA        = CURLOPT!(CURLOPTTYPE_CBPOINT, 202),
    CURLOPT_RESOLVE             = CURLOPT!(CURLOPTTYPE_SLISTPOINT, 203),
    CURLOPT_TLSAUTH_USERNAME    = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 204),
    CURLOPT_TLSAUTH_PASSWORD    = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 205),
    CURLOPT_TLSAUTH_TYPE        = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 206),
    CURLOPT_CLOSESOCKETFUNCTION = CURLOPT!(CURLOPTTYPE_FUNCTIONPOINT, 208),
    CURLOPT_GSSAPI_DELEGATION   = CURLOPT!(CURLOPTTYPE_VALUES, 210),
    CURLOPT_DNS_SERVERS         = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 211),
    CURLOPT_ACCEPTTIMEOUT_MS    = CURLOPT!(CURLOPTTYPE_LONG, 212),
    CURLOPT_TCP_KEEPALIVE       = CURLOPT!(CURLOPTTYPE_LONG, 213),
    CURLOPT_TCP_KEEPIDLE        = CURLOPT!(CURLOPTTYPE_LONG, 214),
    CURLOPT_SSL_OPTIONS         = CURLOPT!(CURLOPTTYPE_VALUES, 216),
    CURLOPT_MAIL_AUTH           = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 217),
    CURLOPT_SASL_IR             = CURLOPT!(CURLOPTTYPE_LONG, 218),
    CURLOPT_XOAUTH2_BEARER      = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 220),
    CURLOPT_DNS_LOCAL_IP4       = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 222),
    CURLOPT_DNS_LOCAL_IP6       = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 223),
    CURLOPT_LOGIN_OPTIONS       = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 224),
    CURLOPT_SSL_ENABLE_ALPN     = CURLOPT!(CURLOPTTYPE_LONG, 226),
    CURLOPT_EXPECT_100_TIMEOUT_MS   = CURLOPT!(CURLOPTTYPE_LONG, 227),
    CURLOPT_PROXYHEADER         = CURLOPT!(CURLOPTTYPE_SLISTPOINT, 228),
    CURLOPT_HEADEROPT           = CURLOPT!(CURLOPTTYPE_VALUES, 229),
    CURLOPT_PINNEDPUBLICKEY     = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 230),
    CURLOPT_UNIX_SOCKET_PATH    = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 231),
    CURLOPT_SSL_VERIFYSTATUS    = CURLOPT!(CURLOPTTYPE_LONG, 232),
    CURLOPT_SSL_FALSESTART      = CURLOPT!(CURLOPTTYPE_LONG, 233),
    CURLOPT_PATH_AS_IS          = CURLOPT!(CURLOPTTYPE_LONG, 234),
    CURLOPT_PROXY_SERVICE_NAME  = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 235),
    CURLOPT_SERVICE_NAME        = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 236),
    CURLOPT_PIPEWAIT            = CURLOPT!(CURLOPTTYPE_LONG, 237),
    CURLOPT_DEFAULT_PROTOCOL    = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 238),
    CURLOPT_STREAM_WEIGHT       = CURLOPT!(CURLOPTTYPE_LONG, 239),
    CURLOPT_STREAM_DEPENDS      = CURLOPT!(CURLOPTTYPE_OBJECTPOINT, 240),
    CURLOPT_STREAM_DEPENDS_E    = CURLOPT!(CURLOPTTYPE_OBJECTPOINT, 241),
    CURLOPT_TFTP_NO_OPTIONS     = CURLOPT!(CURLOPTTYPE_LONG, 242),
    CURLOPT_CONNECT_TO          = CURLOPT!(CURLOPTTYPE_SLISTPOINT, 243),
    CURLOPT_TCP_FASTOPEN        = CURLOPT!(CURLOPTTYPE_LONG, 244),
    CURLOPT_KEEP_SENDING_ON_ERROR   = CURLOPT!(CURLOPTTYPE_LONG, 245),
    CURLOPT_PROXY_CAINFO        = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 246),
    CURLOPT_PROXY_CAPATH        = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 247),
    CURLOPT_PROXY_SSL_VERIFYPEER    = CURLOPT!(CURLOPTTYPE_LONG, 248),
    CURLOPT_PROXY_SSLVERSION    = CURLOPT!(CURLOPTTYPE_VALUES, 250),
    CURLOPT_PROXY_TLSAUTH_USERNAME  = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 251),
    CURLOPT_PROXY_TLSAUTH_PASSWORD  = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 252),
    CURLOPT_PROXY_TLSAUTH_TYPE  = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 253),
    CURLOPT_PROXY_SSLCERT       = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 254),
    CURLOPT_PROXY_SSLCERTTYPE   = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 255),
    CURLOPT_PROXY_SSLKEY        = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 256),
    CURLOPT_PROXY_SSLKEYTYPE    = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 257),
    CURLOPT_PROXY_KEYPASSWD     = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 258),
    CURLOPT_PROXY_SSL_CIPHER_LIST   = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 259),
    CURLOPT_PROXY_CRLFILE       = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 260),
    CURLOPT_PROXY_SSL_OPTIONS   = CURLOPT!(CURLOPTTYPE_LONG, 261),
    CURLOPT_PRE_PROXY           = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 262),
    CURLOPT_PROXY_PINNEDPUBLICKEY   = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 263),
    CURLOPT_ABSTRACT_UNIX_SOCKET    = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 264),
    CURLOPT_SUPPRESS_CONNECT_HEADERS    = CURLOPT!(CURLOPTTYPE_LONG, 265),
    CURLOPT_REQUEST_TARGET      = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 266),
    CURLOPT_SOCKS5_AUTH         = CURLOPT!(CURLOPTTYPE_LONG, 267),
    CURLOPT_SSH_COMPRESSION     = CURLOPT!(CURLOPTTYPE_LONG, 268),
    CURLOPT_MIMEPOST            = CURLOPT!(CURLOPTTYPE_OBJECTPOINT, 269),
    CURLOPT_TIMEVALUE_LARGE     = CURLOPT!(CURLOPTTYPE_OFF_T, 270),
    CURLOPT_HAPPY_EYEBALLS_TIMEOUT_MS   = CURLOPT!(CURLOPTTYPE_LONG, 271),
    CURLOPT_RESOLVER_START_FUNCTION = CURLOPT!(CURLOPTTYPE_FUNCTIONPOINT, 272),
    CURLOPT_RESOLVER_START_DATA = CURLOPT!(CURLOPTTYPE_CBPOINT, 273),
    CURLOPT_HAPROXYPROTOCOL     = CURLOPT!(CURLOPTTYPE_LONG, 274),
    CURLOPT_DNS_SHUFFLE_ADDRESSES   = CURLOPT!(CURLOPTTYPE_LONG, 275),
    CURLOPT_TLS13_CIPHERS       = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 276),
    CURLOPT_DISALLOW_USERNAME_IN_URL    = CURLOPT!(CURLOPTTYPE_LONG, 278),
    CURLOPT_DOH_URL             = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 279),
    CURLOPT_UPLOAD_BUFFERSIZE   = CURLOPT!(CURLOPTTYPE_LONG, 280),
    CURLOPT_UPKEEP_INTERVAL_MS  = CURLOPT!(CURLOPTTYPE_LONG, 281),
    CURLOPT_CURLU               = CURLOPT!(CURLOPTTYPE_OBJECTPOINT, 282),
    CURLOPT_TRAILERFUNCTION     = CURLOPT!(CURLOPTTYPE_FUNCTIONPOINT, 283),
    CURLOPT_TRAILERDATA         = CURLOPT!(CURLOPTTYPE_CBPOINT, 284),
    CURLOPT_HTTP09_ALLOWED      = CURLOPT!(CURLOPTTYPE_LONG, 285),
    CURLOPT_ALTSVC_CTRL         = CURLOPT!(CURLOPTTYPE_LONG, 286),
    CURLOPT_ALTSVC              = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 287),
    CURLOPT_MAXAGE_CONN         = CURLOPT!(CURLOPTTYPE_LONG, 288),
    CURLOPT_SASL_AUTHZID        = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 289),
    CURLOPT_MAIL_RCPT_ALLOWFAILS    = CURLOPT!(CURLOPTTYPE_LONG, 290),
    CURLOPT_SSLCERT_BLOB        = CURLOPT!(CURLOPTTYPE_BLOB, 291),
    CURLOPT_PROXY_SSLCERT_BLOB  = CURLOPT!(CURLOPTTYPE_BLOB, 293),
    CURLOPT_ISSUERCERT_BLOB     = CURLOPT!(CURLOPTTYPE_BLOB, 295),
    CURLOPT_PROXY_ISSUERCERT    = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 296),
    CURLOPT_HSTS_CTRL           = CURLOPT!(CURLOPTTYPE_LONG, 299),
    CURLOPT_HSTS                = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 300),
    CURLOPT_HSTSREADFUNCTION    = CURLOPT!(CURLOPTTYPE_FUNCTIONPOINT, 301),
    CURLOPT_HSTSWRITEFUNCTION   = CURLOPT!(CURLOPTTYPE_FUNCTIONPOINT, 303),
    CURLOPT_AWS_SIGV4           = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 305),
    CURLOPT_DOH_SSL_VERIFYPEER  = CURLOPT!(CURLOPTTYPE_LONG, 306),
    CURLOPT_DOH_SSL_VERIFYHOST  = CURLOPT!(CURLOPTTYPE_LONG, 307),
    CURLOPT_DOH_SSL_VERIFYSTATUS    = CURLOPT!(CURLOPTTYPE_LONG, 308),
    CURLOPT_CAINFO_BLOB         = CURLOPT!(CURLOPTTYPE_BLOB, 309),
    CURLOPT_PROXY_CAINFO_BLOB   = CURLOPT!(CURLOPTTYPE_BLOB, 310),
    CURLOPT_SSH_HOST_PUBLIC_KEY_SHA256  = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 311),
    CURLOPT_PREREQFUNCTION      = CURLOPT!(CURLOPTTYPE_FUNCTIONPOINT, 312),
    CURLOPT_PREREQDATA          = CURLOPT!(CURLOPTTYPE_CBPOINT, 313),
    CURLOPT_MAXLIFETIME_CONN    = CURLOPT!(CURLOPTTYPE_LONG, 314),
    CURLOPT_MIME_OPTIONS        = CURLOPT!(CURLOPTTYPE_LONG, 315),
    CURLOPT_SSH_HOSTKEYFUNCTION = CURLOPT!(CURLOPTTYPE_FUNCTIONPOINT, 316),
    CURLOPT_SSH_HOSTKEYDATA     = CURLOPT!(CURLOPTTYPE_CBPOINT, 317),
    CURLOPT_REDIR_PROTOCOLS_STR = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 319),
    CURLOPT_WS_OPTIONS          = CURLOPT!(CURLOPTTYPE_LONG, 320),
    CURLOPT_CA_CACHE_TIMEOUT    = CURLOPT!(CURLOPTTYPE_LONG, 321),
    CURLOPT_QUICK_EXIT          = CURLOPT!(CURLOPTTYPE_LONG, 322),
    CURLOPT_HAPROXY_CLIENT_IP   = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 323),
    CURLOPT_SERVER_RESPONSE_TIMEOUT_MS  = CURLOPT!(CURLOPTTYPE_LONG, 324),
    CURLOPT_ECH                 = CURLOPT!(CURLOPTTYPE_STRINGPOINT, 325),
    CURLOPT_TCP_KEEPCNT         = CURLOPT!(CURLOPTTYPE_LONG, 326),
}

alias CURLINFO = int;
enum : CURLINFO
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