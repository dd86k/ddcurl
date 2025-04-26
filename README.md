High-level HTTP/WebSocket client using libcurl.

Mostly for personal use.

# Transports

| Name | Depends on | Notes |
|---|---|---|
| HTTPClient | libcurl | |
| WebSocketClient | libcurl (>=7.86+WS or >=8.11) | |

## libcurl

While libcurl starting with version 7.86 implements WebSockets, some operating
systems may not include support for WebSocket, since it is marked as experimental
and it is only an opt-in compile option.

Version 8.11 made WebSocket support official, and should have it available by default.

Those that were checked are listed below. libcurl versions below 7.86 are not listed.

Last checked: 2025-04-26

| OS | Version | libcurl | WebSockets? |
|---|---|---|---|
| Alpine | 3.18 | 8.9.0 | yes |
| Alpine | 3.19 | 8.12.1 | yes |
| Atrix (Arch) | | 8.13.0 | yes |
| CentOS | 10-Stream | 8.12.1 | yes |
| Debian | 12 | 7.88.1 | no |
| Fedora | 39 | 8.2.1 | no |
| Fedora | 40 | 8.6.0 | yes |
| Fedora | 41 | 8.9.1 | yes |
| FreeBSD | 13 | 8.9.1 | no |
| FreeBSD | 14 | 8.12.1 | yes |
| NetBSD | 9 | 8.8.0 | no |
| NetBSD | 10 | 8.12.1 | yes |
| OpenBSD | 10 | 8.9.0 | no |
| OpenSUSE Leap | 15.6 | 8.6.0 | no |
| OpenSUSE Tumbleweed | | 8.13.0 | yes |
| Rocky Linux | 9 | 7.76.1 | no |
| Salix (Slackware) | 15.0 | 8.13.0 | yes |
| Ubuntu | 24.04 | 8.5.0 | no |
| Void Linux | | 8.9.1 | yes |