import os
from pathlib import Path


def read_output(filename: str) -> str:
    path = Path(filename)

    if not path.exists():
        return "No output was produced."

    output = path.read_text(encoding="utf-8", errors="replace").strip()

    return output if output else "No issues found."


def status_icon(success: bool) -> str:
    return "OK" if success else "FAIL"


# GitHub exposes the exit status of each step through the environment.
#
# We pass these explicitly from the workflow below.
build_ok = os.environ.get("BUILD_OK") == "true"
format_ok = os.environ.get("FORMAT_OK") == "true"
lint_ok = os.environ.get("LINT_OK") == "true"

build_output = read_output("build_output.txt")
format_output = read_output("format_output.txt")
lint_output = read_output("linter_output.txt")

summary = f"""# Build Summary

| Check | Status |
| --- | --- |
| Build | {status_icon(build_ok)} |
| Formatting | {status_icon(format_ok)} |
| ZLint | {status_icon(lint_ok)} |

# Tasks

## Compiler
```
{build_output}
```

## Formatter
{format_output}

## Linter
{lint_output}
"""

summary_file = os.environ.get("GITHUB_STEP_SUMMARY")

if not summary_file:
    raise RuntimeError("GITHUB_STEP_SUMMARY is not set")

with open(summary_file, "a", encoding="utf-8") as f:
    _ = f.write(summary)
