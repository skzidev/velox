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

If you're contributing code, you're probably going to want to run our test suite. In order to do this, clone the repository, while keeping symlinks.

Then, plug in a brain and run `zig build test`. This will build and upload the tests to your brain.

After that, run `cargo v5 terminal`, and press the 8th slot on your brain, then press "run".

This will run the unit test suite.
