# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

javaenv is a Java version manager (like rbenv/nvm) written in pure Bash. It installs JDKs from Eclipse Adoptium and manages versions via shims and `.javaversion` files. No build system or external dependencies beyond curl and standard Unix tools.

## Key Files

- `javaenv` — Main CLI script (~350 lines of Bash). Contains all commands and shim generation logic.
- `install` — One-step installer that copies `javaenv` to `~/.local/share/javaenv/bin/` and symlinks to `~/.local/bin/`.
- `Formula/javaenv.rb` — Homebrew formula.

## Testing

The only automated test is in the Homebrew formula (`Formula/javaenv.rb`), which asserts `javaenv help` output. No test suite exists. To manually verify:

```bash
./javaenv help
./javaenv install --list
```

## Architecture

**Version resolution:** `.javaversion` file lookup — shims walk up the directory tree from `$PWD`, falling back to `~/.javaversion`. The main CLI's `resolve_version()` only checks cwd and home (simpler than the shim version).

**Shim system:** `cmd_reshim()` generates wrapper scripts in `~/.local/bin/` for 25+ Java executables (java, javac, etc.). Each shim embeds its own `resolve_version()` that traverses parent directories. Shims detect and skip overwriting non-javaenv files.

**Adoptium API integration:** Uses `https://api.adoptium.net/v3/` for version listing and binary downloads. JSON is parsed with sed/awk to avoid requiring jq or python3.

**Platform detection:** `detect_os()` and `detect_arch()` map uname output to Adoptium API parameters. macOS JDK tarballs have a `Contents/Home` nesting that gets flattened during install.

**Storage layout:**
- `~/.local/share/java/<version>/` — Installed JDKs
- `~/.local/bin/` — Shim scripts
