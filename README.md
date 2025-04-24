High-level HTTP/WebSocket client using libcurl.

Mostly for personal use.

# Transports

| Name | Depends on | Notes |
|---|---|---|
| HTTPClient | libcurl | |
| WebSocketClient | libcurl (>=7.86 with WS or >=8.11) | |

## libcurl

While libcurl starting with version 7.86 implements WebSockets, some operating
systems may not include support for WebSocket, since it is marked as experimental
and it is only an opt-in compile option.

Those that were checked are listed below. libcurl versions below 7.86 are not listed.

| OS | Version | libcurl | WebSockets? |
|---|---|---|---|
| Alpine | 3.18 | 8.9.0 | yes |
| Atrix (Arch) | | 8.9.1 | no |
| Debian | 12 | 7.88.1 | no |
| Fedora | 39 | 8.2.1 | no |
| Fedora | 40 | 8.6.0 | yes |
| FreeBSD | 13, 14 | 8.9.1 | no |
| NetBSD | 9, 10 | 8.8.0 | no |
| OpenBSD | 10 | 8.9.0 | no |
| OpenSUSE Leap | 15.6 | 8.6.0 | no |
| OpenSUSE Tumbleweed | | 8.9.1 | no |
| Salix (Slackware) | 15 | 8.9.1 | no |
| Solus | 4.5 | 8.9.1 | no |
| Ubuntu | 24.04 | 8.5.0 | no |
| Void Linux | | 8.9.1 | yes |