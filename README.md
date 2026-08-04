# Zeolite Kernel

**A modern, safe, and easy-to-use kernel for the VEX V5 Brain, in Zig.**

> [!WARNING]
> Zeolite has not hit alpha yet. It has yet to undergo stress-testing. It is actively being developed.

## Why use Zeolite?

Existing options (like PROS) lack safety nets.

- Zeolite is designed to be safe. It is engineered in Zig to strike the perfect balance between safety and easy-to-fix errors.
- Modern tooling. Avoid `#include` nightmares. Use `@import`. Nice and simple.
- Easy-to-read runtime errors. Tired of cryptic runtime errors? Great. We fix that.

## Acknowledgements

This project would not have been possible if these two projects did not open-source their findings:

- [PROS](https://pros.cs.purdue.edu/)
- [Vexide](https://vexide.dev/)

Zeolite builds on their research into the Brain's memory model and configuration.

## Roadmap

- [x] Write boot code
- [x] Custom Allocator Override
- [x] Panic handler with stack traces
- [x] Jumptable integration
- [ ] Device Drivers
- [ ] Odometry, Control, & Localization Library

## Competition Legality

According to rule `<R8>` of the Override Game Manual, custom firmware modifications are not permitted. Zeolite is a kernel, but it is still a user program. Like PROS and Vexide, it should be considered **legal** unless VEX specifically bans it.

## Getting Started

#### Prerequisites

1. Zig 0.16 (`zvm` is recommended if you need more Zig versions)
2. cargo-v5 (for uploading code to the brain)
3. A V5 brain.

#### Building

Plug in the V5 Brain, then run these commands:

```bash
# Clone the repository
git clone https://github.com/skzidev/zeolite-kernel.git
cd zeolite-kernel

# Build the kernel and upload it
zig build upload
```
