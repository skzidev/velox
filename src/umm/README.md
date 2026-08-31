# Velox-umm

This is a fork of [umm-zig](https://github.com/ZigEmbeddedGroup/umm-zig) that works with Zig 0.16. It was initially developed and published by the Zig Embedded Group.
It's a memory allocator designed for targets with limited RAM, and is used in Velox as the default backing allocator (overrides std.heap.page_allocator).

> [!NOTE]
> The original Zlib license for `umm-zig` is kept in [LICENSE](./LICENSE).
