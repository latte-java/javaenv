# javaenv vs jenv Comparison

## What javaenv already does better

- **Installs JDKs** — jenv only switches between pre-installed JDKs; javaenv downloads from Adoptium directly.
- **Zero shell init required** — javaenv shims work standalone without `eval "$(jenv init -)"` in your shell rc.
- **Simpler, leaner** — ~350 lines vs jenv's 45+ scripts in libexec.

## Features worth considering

### High value

1. **`JAVA_HOME` export** — javaenv doesn't set `JAVA_HOME`. Many build tools (Maven, Gradle, IDEs) read `JAVA_HOME` directly and ignore PATH shims. jenv requires a plugin for this; javaenv could do it by default in shims via `export JAVA_HOME=...` before exec, or provide a `javaenv init` that sets it on shell startup.

2. **`shell <version>` command** — Temporary per-session override via an env var (`JENV_VERSION`). javaenv only resolves from `.javaversion` files. An env var override (e.g., `JAVAENV_VERSION`) would let users switch versions without creating files.

3. **`global <version>` / `local <version>` commands** — Instead of requiring users to manually `echo 21.0.7+6 > .javaversion`, these commands write the version file for you with validation that the version is actually installed.

4. **`doctor` command** — Diagnoses common problems: is PATH set up correctly, are shims ahead of system java, is JAVA_HOME conflicting, etc. Very helpful for troubleshooting.

### Medium value

5. **`add <path>` command** — Register an already-installed JDK (e.g., from Homebrew or a vendor installer). javaenv currently only manages JDKs it downloaded itself. Supporting external JDKs via symlinks would cover more use cases.

6. **Shell completions** — jenv ships bash/zsh completions. Tab-completing version numbers and commands is a nice UX improvement.

7. **`which <command>` / `prefix` commands** — Show the resolved path for a command or the active JDK's root. Useful for debugging and for scripts that need the path programmatically (`javaenv home` partially covers this).

8. **Build tool integration (Maven/Gradle)** — jenv sets `MAVEN_OPTS` and `GRADLE_OPTS` via plugins so build tools pick up the right JDK even when invoked indirectly. This matters when tools spawn subprocesses that don't inherit PATH shims.

### Lower value (consider later)

9. **Major version aliases** — jenv creates symlinks like `21`, `21.0`, `21.0.2`, and `openjdk64-21.0.2` so users can say `jenv local 21` without knowing the full version. javaenv requires exact versions. *(Design spec written — 2026-03-26-major-version-aliasing-design.md)*

10. **JVM options management** — `global-options`, `local-options` for setting JVM flags per-project or globally. Niche but useful for teams standardizing flags.

11. **`with <version> <command>`** — Run a one-off command with a specific JDK without changing any state. Handy for testing across versions.

12. **Fish shell support** — jenv marks it experimental, but having `javaenv init` for fish/bash/zsh would help with JAVA_HOME integration.

## jenv limitations that javaenv should avoid

- **JAVA_HOME not set by default** — jenv requires explicitly enabling an "export" plugin. This is a common source of confusion.
- **Shell startup cost** — `eval "$(jenv init -)"` runs `jenv rehash` on every new shell, scanning all version directories.
- **Multiple aliases cause confusion** — A single `jenv add` creates 3-4 symlinks that all appear in `jenv versions`.
- **Fish shell is experimental** — Marked as untested, requires manual file copying.
- **Vendor detection is fragile** — `jenv add` matches vendor names from `java -version` output using string matching.
