---
ctf: UMDCTF
title: A Minecraft Movie
authors:
    - name: tahmid-23
      url: https://tzaman.dev
description: I...AM STEVE!
categories:
    - Web
year: 2025
challengefiles: a-minecraft-movie
published: "2025-02-04"
optional:
    writeup_winner:
        label: Best web writeup 2025
        proof_url: https://discord.com/channels/938193497306067065/938196910039269406/1412823165213605959
---

# TL;DR<a id="TL;DR"></a>

    **- Challenge Setup:** **React** webapp with account management to create simple posts and let it rate by the others and the admin - you get the flag if the admin likes your post
    **- Key Discoveries:** Client-side XSS sanitization with **DOMPurify**
    **- Vulnerability:** HTML injection in the content of posts
    **- Exploitation:** There were several ways of exploiting the 1 click of the admin to get CSRF from a simple form submit to a clickjacking styled attack to CSS shenanigans to DOM clobbering and finally just 🧀 the challenge by logging into others' accounts

# 1. Introduction<a id="introduction"></a>

While this wasn't the most complex challenge, it was refreshing to see a challenge with so many different solutions. Beyond my solution, I'll be discussing a bunch of alternative approaches from the **UMDCTF** Discord after the CTF ended. So thanks to everyone who shared their ideas and payloads!

# 2. Reconnaissance<a id="reconnaissance"></a>

We are given two URLs: one for the website itself and one to submit a post ID to the admin (everything else than a post ID will be rejected) - a typical XSS/CSRF challenge setup. Starting with the challenge we are greeted by a wonderful landing page containing different posts. As the theme of this year's **UMDCTF** was all about brainrot social media, this challenge was about a **Minecraft movie** fanclub website where people can submit, like, and dislike each other's posts on a shared instance. Having a look into one of the posts reveals users can add embedded **YouTube** links via iframes. But more important we see a small hint `🌟 This post was liked by an admin!`.

![landing overview](ctf/writeups/umdctf/aminecraftmovie/landingoverview.png "landing overview")

So it is quite obvious we have to make the admin like our post. Creating our Account, we can see the following dashboard:

![account overview](ctf/writeups/umdctf/aminecraftmovie/accountoverview.png "account overview")

But there is something weird with the `session number`, it tells us it is `undefined`. This will be more important later for the [DOM clobbering exploit](#exploitation%20variant%201). Creating a new post with some `<b>` HTML tag will reveal that we effectively got HTML injection:

![post testing](ctf/writeups/umdctf/aminecraftmovie/posttesting.png "post testing")

Moreover, sending any post to the admin reveals, he will always click the `dislike` button. Going further and trying some `<script>` tag reveals there is some kind of sanitizer, removing malicious HTML, as no alert box pops up. Let's look at the response in **Burp Suite** to figure out what happened:

![xss test](ctf/writeups/umdctf/aminecraftmovie/xsstest.png "xss test")

We see the script tag isn't sanitized by some backend. There has to be a client-side sanitizer. Investigating the `index.js` running in our browser, we find **DOMPurify** v3.2.5, a powerful XSS sanitizer running in its latest version. It is very unlikely that we have to find a bypass for this sanitizer, as you would need a zero-day vulnerability for this. So we have to come up with some other ideas.

# 3. Vulnerability Description<a id="vulnerability description"></a>

Liking one of our posts and coming back to our account Dashboard, we won't see `Current Session Number: undefined` anymore, but now it shows the number of likes we have given to posts. Having a closer look at the request made reveals some `legacy-social` endpoint:

![liking a post](ctf/writeups/umdctf/aminecraftmovie/sessionnumberinlikingpost.png "liking a post")

So the `session number` is always submitted with our POST request when a post is liked. As we saw earlier, `Current Session Number: undefined`, this is maybe just a `window` object property, so let's test our assumption. And indeed, as we type in `window`, it will already suggest `window.sessionNumber` which has the same number we see on our dashboard. Also, checking out the HTML of an arbitrary post gives us a hint in a HTML comment:
`<!-- TODO: Migrate social endpoint, switch to useState/useContext -->`
So instead of some native **React** functionality to manage some kind of state, the developers of this website just used a global **JavaScript** object.

# 4. Exploitation<a id="exploitation"></a>

## 4.1. Exploitation Variant 1 - DOM Clobbering<a id="exploitation variant 1"></a>

In short, DOM clobbering is about changing the way **JavaScript** works on a website by injecting specific HTML content. By setting the `id` attribute of some HTML tag to a used `window` object property, we can overwrite the value of this global **JavaScript** object or variable. In this case, `sessionNumber` is a great target as we see in following code snippet to handle the dislike button:

```javascript
const handleLikeDislike = useCallback(async (likesChange) => {
  await startSessionIfNeeded();

    if (window.sessionNumber === undefined) {
      setSocialError("Session not started. Cannot like/dislike.");
            return;
    }
    try {
      const response = await fetch(`${API_BASE_URL}/legacy-social`, {
        method: "POST",
            headers: {
              "Content-Type": "application/x-www-form-urlencoded"
            },
            body: `sessionNumber=${window.sessionNumber}&postId=${postId}&likes=${likesChange}`,
            credentials: "include"
        });
        if (!response.ok) {
          setSocialError(await response.text());
            return;
        }
        await fetchPost();
    } catch (err) {
      setSocialError("Failed to update likes.");
            console.error("Like/dislike error:", err);
    }
}, [postId, fetchPost]);
```

As the `sessionNumber` is simply concatenated with the other HTTP request data we can create a post with content like `<a href="&likes=10" id="sessionNumber">gimme dat like</a>`. This will result in a new key-value pair `likes` by simply setting `&` at the start of the `href` attribute. The `href` attribute will overwrite the value of the `sessionNumber` window property. The request will look like this:

![dom clobbered session number](ctf/writeups/umdctf/aminecraftmovie/domclobberedsessionnumber.png "dom clobbered session number")

The backend will take the first `likes` key-value pair and although we clicked the dislike button, we will contribute a like to the post. Sending the post ID to the admin will result in:

![admin liked](ctf/writeups/umdctf/aminecraftmovie/adminliked.png "admin liked")

Returning to our account overview, we are greeted with the flag:

![flag](ctf/writeups/umdctf/aminecraftmovie/flag.png "flag")

## 4.2. Exploitation Variant 2 - Submit Form<a id="exploitation variant 2"></a>

The simplest method to get CSRF without any **JavaScript** but with a click is via submit forms. The only obstacle is that the admin will always click the button with the id `dislike-button`. But something interesting will happen if we just add another HTML element with the same ID. Technically, this is invalid HTML. But as browsers always try their best to fix invalid HTML, this rule is ignored and the document is still being rendered. However, DOM access via `window.document.getElementById('dislike-button')` will return the first element in the DOM with this specific id. This is just an assumption, but the probability is high that the admin is implemented with selenium/puppeteer to automate admin requests. As the admin bot just simulates a click on the button with id `dislike-button`, it will search the DOM and will receive the first one being ours. So we can just add a random post and a second one, like following:

```html
<form action="https://a-minecraft-movie-api.challs.umdctf.io/legacy-social"
    method="post">
    <input type="hidden" name="postId" value="<some-post-id>">
    <input type="hidden" name="likes" value="1">
    <button id="dislike-button" type="submit">Get this juice like</button>
</form>
```

The admin will click our submit form and thus like our other post.

## 4.3. Exploitation Variant 3 - iframe YouTube Open Redirect<a id="exploitation variant 3"></a>

There was another great idea to solve this challenge. As you have an HTML injection, we can try to redirect the admin to our website. As the web server has no CSRF protection, we can simply host an automated submit form, so the admin will like our post. Starting with the redirect, we have a little problem:

```javascript
const dirtyHTML = f.content;
const cleanHTML = DOMPurify.sanitize(dirtyHTML, {
  ADD_TAGS: ["iframe"],
  ADD_ATTR: ["allow", "allowfullscreen", "frameborder", "scrolling", "src", "width", "height"]
});

...

DOMPurify.addHook("uponSanitizeElement", (node, data) => {
  if (data.tagName === "iframe" && node instanceof Element) {
    const src = node.getAttribute("src") || "";
    if (!src.startsWith("https://www.youtube.com/embed/")) {
      node.parentNode.removeChild(node);
    }
  }
});
```

We are allowed to embed content in iframes, but only from **YouTube**. So we need an **open redirect**. The first one is in **YouTube** itself, but it is restricted as it only allows you to redirect to **Google** domains via: `https://www.youtube.com/embed/../logout?continue=https://google.com`. The second **open redirect** is in the **Googleads** product and thus allows us to chain these **open redirects** like the following:

```html
<iframe src="https://www.youtube.com/embed/../logout?continue=https://googleads.g.doubleclick.net/pcs/click?adurl=<your-own-website>"></iframe>
```

Now we can host the following HTML with an appropriate post ID on our website, which leads to CSRF:

```html
<script>
fetch('https://a-minecraft-movie-api.challs.umdctf.io/legacy-social', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/x-www-form-urlencoded',
  },
  body: 'sessionNumber=1&postId=<post-id>&likes=1',
  credentials: 'include'
});
</script>
```

The iframe will be victim to the **open redirects**. The reason for this is the cookie attribute `sameSite=none`, you can read further in [this article](https://portswigger.net/web-security/csrf/bypassing-samesite-restrictions#none) describing this attribute in depth. This means the browser will always send the cookie to the challenge website in all requests, no matter by whom they were issued. So when the iframe is redirected to our malicious website, the POST request will be submitted together with the admin cookie. The cool thing about this exploit is that we don't even need the click of the admin.

## 4.4. Exploitation Variant 4 - CSS Shenanigans<a id="exploitation variant 4"></a>

This one is a bit more special, but I like the idea. It is a clickjacking-like approach to solve this challenge. The main idea is to add another button with the id `dislike-button`, just like in the [submit-form-approach](#exploitation%20variant%202). But this time we will move our button behind the like button with CSS. The admin bot will just search for this button via the id attribute and then click on the element. You might think at first that, puppeteer will click the element even when it is overlapped by another element. But reading the documentation about puppeteer [click handler](https://pptr.dev/api/puppeteer.elementhandle.click), we will get the information that it simulates a real mouse click. So it will focus on the element given by a selector, but will still click the topmost element. So we just add a post with the following content:

```html
<div id="dislike-button" style="position:absolute; transform:translateX(305px) translateY(17px); z-index:-1;">I love CSS</div>
```

The button will be covered by the like button and thus submitting this to the admin will lead to a like for our post.

## 4.5. Exploitation Variant 5 - I…LOVE CHEESE!🧀<a id="exploitation variant 5"></a>

This is one of the oldest cheeses in CTF and also applies in the real world. In general, if you have a weak password policy, people will use bad username-password combinations. Especially when time is a factor, like in CTF challenges. So you can expect some bad credentials and try to guess them like for example `asdfasdf:asdfasdf`. Logging in will get you the flag without even exploiting the actual challenge.

# 5. Mitigation<a id="mitigation"></a>

Although **DOMPurify** was present on this website to sanitize user input, some mistakes were made. Effectively giving users HTML injection always opens doors for attackers. If you want your users to style their content, then you might want to use a markdown parser or something similar, as these have a more restrictive way to style content. Moreover, allowing **YouTube** links to be embedded opens the door for **open redirects**, as we already saw. There is no reason for `sameSite=none`, especially if users can add iframes. Instead, use the default value `Lax` or even `Strict`. Also, the use of global **JavaScript** objects like `window.sessionNumber` should be prevented when requests are depending on it. Instead, use (as the **TODO** in the HTML file already hints) native functionality in **React** like `useState` or `useContext`. Another mistake was to set up the challenge with a shared instance. Depending on the challenge this is not always a bad idea, but together with a weak password policy and having the flag just right there in the dashboard of the accounts will always lead to lazy players logging into others' accounts and stealing their flags. To summarize, having another user clicking on your content can be very powerful and should always remind us to think twice when clicking on unknown content.

# 6. Flag<a id="flag"></a>

UMDCTF{I_y3@RNeD_f0R_7HE_Min3S}
