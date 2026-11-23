# Contributing

Thanks for wanting to contribute!

# Ways to contribute

## Issues/Bug Reports

Before making a bug report, ensure one doesn't already exist. Go to Issues and try to find an entry that describes your issue. If the issue is closed, you can open a new one, but you should tag the first issue.

In issues, try to:

- Give it a clear title
- Clearly illustrate the issue. Ideally, use screenshots or code snippets which demonstate the issue.
- Provide version information:
  - Zig Version
  - Velox Version
  - Operating system
- Describe when you noticed the issue

## Feature suggestions

Feature suggestions are great, but they should be **in scope of the project**.

Features like controllers, odometry tracking, or localization aren't a part of this project, they're a part of a separate controls library.

## Contributing code

Our CI checks formatting and will fail if formatting is incorrect. You should run `zig fmt src/ mock/ runner/` before creating a PR for the code. Better yet, if you don't mind, enable "format on save" in your editor.

> [!NOTE]
> Commit messages should use Conventional commits

# Running Tests

If you're contributing code, you may want to run the test suite. Clone the repository while preserving symlinks.

Build the on-hardware test artifact:

```sh
zig build test
```

This produces `zig-out/bin/velox-test`. Upload it to a V5 brain (for example with `cargo v5 upload`), then monitor serial output with `cargo v5 terminal` and run the program on the brain.
