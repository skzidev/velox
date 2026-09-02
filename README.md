<p align="center"><img src="assets/demo.png" style="margin: 0 auto; display: block;"></p>

<br>

<h1 align="center">Velox</h1>

<p align="center"><strong>Open Source Zig Framework for VEX V5.</strong></p>

<p align="center">
  <img src="https://img.shields.io/github/actions/workflow/status/skzidev/velox/build.yml?style=for-the-badge" alt="GitHub Actions Workflow Status">
  <img src="https://img.shields.io/github/license/skzidev/velox?style=for-the-badge" alt="GitHub License">
  <img src="https://img.shields.io/badge/Zig-0.16.0-color?logo=zig&color=%23f3ab20&style=for-the-badge" alt="Zig support">
  <img src="https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fraw.githubusercontent.com%2Fskzidev%2Fvelox%2Frefs%2Fheads%2Fmain%2Fbuild.zig.zon&search=%5C.version%20%3D%20%22(%5Cd%5C.%5Cd%5C.%5Cd)%22&replace=%241&style=for-the-badge&label=Version" alt="Velox Version">
</p>

## Getting Started

To get started using Velox, create a new project folder and run this command:

```sh
curl -fsSL "https://raw.githubusercontent.com/skzidev/velox/refs/heads/main/new_project.sh" | sh
```

## Roadmap

- [x] Write boot code
- [x] Custom Allocator Override
- [x] Panic handler with stack traces
- [x] Jumptable integration
- [x] Device Drivers (_partially done_)
- [ ] Custom Uploader program
- [ ] GUI library (Potentially written on top of a library like [Knots](https://codeberg.org/shahwali/knots))

#### Additional work

- [ ] Refactor `velox-jumptable` to just read from C header files and map memory addresses instead of generating bindings
- [ ] Refactor `velox-jumptable` into this monorepo

## Modules

- [Kernel](./src/kernel/README.md)
- [SDK](./src/sdk/README.md)
- [Umm](./src/umm/README.md)
- [Jumptable](https://github.com/skzidev/velox-jumptable)

## Competition Legality

According to rule `<R8>` of the Override Game Manual, custom firmware modifications are not permitted. Velox is a user program. Like PROS and Vexide, it should be 100% fair game, so long as you understand what it does.

## Licensing

Velox's original code is licensed under the MIT license, **however, `umm-zig` is licensed under the Zlib license, and therefore `velox-umm` is licensed under Zlib as well**.

## Acknowledgements

This project would not have been possible without the research from these projects and teams:

- [PROS](https://pros.cs.purdue.edu/)
- [Vexide](https://vexide.dev/)
- [38535B High Stakes Source](https://github.com/tubaplayerdis/Gold4Team3CompProj)
- [vex-v5-research](https://github.com/hatf0/vex-v5-research/tree/master)
- [VEXAPI](https://github.com/cetio/VEXAPI)

Velox builds on their research into the Brain's memory model and configuration.

## Tests

Tests are written in Zig's testing framework, and their results are logged over serial. They run inside of a custom test runner which is itself written using Velox as a program. To run them yourself:

```sh
zig build test
```

The results are written to serial.
