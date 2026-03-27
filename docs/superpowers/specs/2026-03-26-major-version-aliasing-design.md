# Major Version Aliasing

## Problem

javaenv requires exact version strings everywhere — both for `javaenv install 21.0.7+6` and in `.javaversion` files. Users should be able to say `javaenv install 21` to get the latest JDK 21, and put `21` in `.javaversion` to use the latest installed JDK 21.

## Design

### `javaenv install <major>`

When the version argument contains no dots (e.g., `21`), resolve it to the latest GA release before proceeding with the normal install flow.

**Resolution:** Query the Adoptium API with a version range filter:

```
https://api.adoptium.net/v3/info/release_versions?page_size=1&release_type=ga&vendor=eclipse&os={os}&architecture={arch}&image_type=jdk&sort_order=DESC&version=[{major},{major+1})
```

Parse the response to extract the full version string (e.g., `21.0.7+6`), then proceed with `cmd_install` as normal. The installed directory remains the full version string — no new symlinks or alias files.

### Major-only `.javaversion`

When a shim reads a version string with no dots from `.javaversion`:

1. Scan directories in `~/.local/share/java/`
2. For each directory name, strip any non-numeric prefix (e.g., `jdk-`) to extract the version number
3. Match entries whose extracted version starts with `{major}.`
4. Sort matches by version (numeric comparison of each segment) and pick the highest
5. Use that directory as the JDK path

If no installed version matches, error with: `javaenv: no JDK {major}.x installed. Run: javaenv install {major}`

### What doesn't change

- Full version strings (`21.0.7+6`) work exactly as today in both `install` and `.javaversion`
- `javaenv versions` lists installed versions by their actual directory names
- `javaenv current` shows the actual resolved version, not just the major number
- No symlinks, alias files, or other new state is introduced

## Touch Points

1. **`cmd_install()`** — Detect major-only input (no dots in version string). Query Adoptium API to resolve to full version, then continue with existing install logic.
2. **Shim template in `cmd_reshim()`** — Update the embedded `resolve_version()` function. After reading the version from `.javaversion`, if the value has no dots, scan the java directory for the highest matching installed version.
3. **`resolve_version()` in main script** — No changes. It reads and returns the file contents; interpretation happens at point of use.

## Version Sorting

When multiple JDK versions match a major (e.g., `21.0.5+8` and `21.0.7+6`), sort by splitting on `.` and `+` and comparing each numeric segment. The highest wins.
