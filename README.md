<p align="center"><img src="assets/demo.png" style="margin: 0 auto; display: block;"></p>

<br>

<h1 align="center">Velox</h1>

<p align="center"><strong>A Zig platform for VEX V5.</strong></p>

> [!WARNING]
> Velox has not hit alpha yet. It can boot on the brain, allocate memory, render graphics, and call VEX SDK bindings, but concurrency, competition and device APIs are being developed.

## Project Structure

Velox is split into packages:

- `velox-core`: Contains boot and startup code. It handles initialization and is the entrypoint for Velox programs. Its build script handles building everything, so the user's build script just
- `velox-jumptable`: Contains programmatically generated bindings to the [VEX jumptable](https://internals.vexide.dev/sdk/#jumptable) and the code that generated them.
- `velox-umm`: A fork of [umm-zig](https://github.com/ZigEmbeddedGroup/umm-zig) that works with Zig 0.16. It is the default allocator, and overrides `std.heap.page_allocator`.
- `velox-sdk` (planned): Contains wrapper functions to jumptable bindings to make user code easier to write.

## Roadmap

- [x] Write boot code
- [x] Custom Allocator Override
- [x] Panic handler with stack traces
- [x] Jumptable integration
- [ ] Device Drivers
- [ ] Odometry, Control, & Localization Library

## Competition Legality

According to rule `<R8>` of the Override Game Manual, custom firmware modifications are not permitted. Velox is a user program. Like PROS and Vexide, it should be 100% fair game, so long as you understand what it does.

## Acknowledgements

This project would not have been possible without the research from these projects and teams:

- [PROS](https://pros.cs.purdue.edu/)
- [Vexide](https://vexide.dev/)
- [38535B High Stakes Source](https://github.com/tubaplayerdis/Gold4Team3CompProj)
- [vex-v5-research](https://github.com/hatf0/vex-v5-research/tree/master)
- [VEXAPI](https://github.com/cetio/VEXAPI)

Velox builds on their research into the Brain's memory model and configuration.

## Getting Started

#### Prerequisites

1. Zig 0.16 (`zvm` is recommended if you need more Zig versions)
2. cargo-v5 (for uploading code to the brain)
3. A V5 brain.

#### Building

Plug the V5 Brain into your computer, then run these commands:

```bash
# Clone the repository
git clone https://github.com/skzidev/Velox-core.git
cd velox-core

# Build and upload it
zig build upload
```
