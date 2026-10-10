# MiniZip Read-Only Integration

The five unmodified `unzip.c`, `unzip.h`, `ioapi.c`, `ioapi.h`, and `ints.h` files are
vendored from [zlib v1.3.2](https://github.com/madler/zlib/tree/v1.3.2/contrib/minizip).
Copyright and zlib license notices are preserved in the source headers.

Only the reader is compiled. `unzip.c` is built with `NOUNCRYPT` to disable
encrypted archives. Compression uses the Apple SDK's system `libz`.
There is no network dependency during App builds or runtime.

`NCELessonResourceStore` reads individual entries into bounded memory buffers,
checks CRCs, and caches ZIP directory positions. It never extracts to disk or
accepts downloaded or user-supplied archives.
