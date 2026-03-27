# Major Version Aliasing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow `javaenv install 21` and `.javaversion` containing `21` to resolve to the latest available/installed JDK for that major version.

**Architecture:** Two changes to the single `javaenv` script: (1) a new `resolve_latest_major()` function that queries the Adoptium API to find the latest full version for a major, called from `cmd_install()`, and (2) a new `resolve_major_to_installed()` function (in both the main script and the shim template) that scans installed JDKs to find the highest version matching a major number.

**Tech Stack:** Bash, curl, Adoptium REST API

---

### File Map

- **Modify:** `javaenv` — all changes are in this single file
  - Add `resolve_latest_major()` helper (~line 46, after `detect_arch`)
  - Add `resolve_major_to_installed()` helper (after `resolve_latest_major`)
  - Modify `cmd_install()` (~line 96) to detect major-only input
  - Modify `cmd_current()` (~line 188) to resolve major-only versions
  - Modify `cmd_home()` (~line 206) to resolve major-only versions
  - Modify `cmd_versions()` (~line 167) to resolve major-only for current marker
  - Update shim template in `cmd_reshim()` (~line 232) to handle major-only resolution
  - Update `usage()` help text (~line 277)

No new files created. No test infrastructure exists, so verification is manual via `javaenv help` and reading the generated shim output.

---

### Task 1: Add `resolve_latest_major()` to resolve major version via Adoptium API

**Files:**
- Modify: `javaenv:46` (insert after `detect_arch()`)

- [ ] **Step 1: Add `resolve_latest_major()` function**

Insert after `detect_arch()` (after line 46):

```bash
resolve_latest_major() {
  local major="$1"
  local os arch api_url json version
  os="$(detect_os)"
  arch="$(detect_arch)"

  local next_major=$((major + 1))
  api_url="https://api.adoptium.net/v3/info/release_versions?page_size=1&release_type=ga&vendor=eclipse&os=${os}&architecture=${arch}&image_type=jdk&sort_order=DESC&version=%5B${major},${next_major})"

  if ! json="$(curl -fsSL "${api_url}")"; then
    echo "Error: Failed to query Adoptium API for JDK ${major}" >&2
    exit 1
  fi

  # Extract version: build, major, minor, security from first result
  version="$(echo "${json}" \
    | tr -d ' \n' \
    | sed 's/.*"build":\([0-9]*\),.*"major":\([0-9]*\),"minor":\([0-9]*\),.*"security":\([0-9]*\).*/\2.\3.\4+\1/')"

  if [[ -z "${version}" || "${version}" == "${json}" ]]; then
    echo "Error: No GA release found for JDK ${major}" >&2
    exit 1
  fi

  echo "${version}"
}
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n javaenv`
Expected: no output (clean parse)

- [ ] **Step 3: Commit**

```bash
git add javaenv
git commit -m "feat: add resolve_latest_major() for Adoptium API lookup"
```

---

### Task 2: Add `resolve_major_to_installed()` for local version matching

**Files:**
- Modify: `javaenv` (insert after `resolve_latest_major()`)

- [ ] **Step 1: Add `resolve_major_to_installed()` function**

Insert immediately after `resolve_latest_major()`:

```bash
resolve_major_to_installed() {
  local major="$1"
  local best=""
  local best_parts=()

  for dir in "${JAVAENV_JAVA_DIR}"/*/; do
    [[ -d "${dir}" ]] || continue
    local name
    name="$(basename "${dir}")"

    # Strip any non-numeric prefix (e.g., "jdk-")
    local ver="${name#"${name%%[0-9]*}"}"

    # Check if this version starts with the requested major
    local dir_major="${ver%%.*}"
    if [[ "${dir_major}" != "${major}" ]]; then
      continue
    fi

    # Compare version segments to find the highest
    if [[ -z "${best}" ]]; then
      best="${name}"
      continue
    fi

    # Split both versions on . and + for numeric comparison
    local IFS='.+'
    local -a cur_parts=(${ver})
    local -a best_ver="${best#"${best%%[0-9]*}"}"
    local -a best_parts=(${best_ver})
    IFS=' '

    local i
    for ((i = 0; i < ${#cur_parts[@]}; i++)); do
      local cur_seg="${cur_parts[$i]:-0}"
      local best_seg="${best_parts[$i]:-0}"
      if (( cur_seg > best_seg )); then
        best="${name}"
        break
      elif (( cur_seg < best_seg )); then
        break
      fi
    done
  done

  if [[ -z "${best}" ]]; then
    echo ""
    return
  fi

  echo "${best}"
}
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n javaenv`
Expected: no output (clean parse)

- [ ] **Step 3: Commit**

```bash
git add javaenv
git commit -m "feat: add resolve_major_to_installed() for local version matching"
```

---

### Task 3: Update `cmd_install()` to handle major-only input

**Files:**
- Modify: `javaenv:96-98` (`cmd_install()` function)

- [ ] **Step 1: Add major-only detection at the top of `cmd_install()`**

Replace lines 97-98:

```bash
  local version="$1"
  local os arch release_name url dest tmp_dir archive_ext
```

With:

```bash
  local version="$1"

  # If version has no dots, treat as major version — resolve to latest GA
  if [[ "${version}" != *.* ]]; then
    echo "Resolving latest JDK ${version}..."
    version="$(resolve_latest_major "${version}")"
    echo "Latest version: ${version}"
  fi

  local os arch release_name url dest tmp_dir archive_ext
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n javaenv`
Expected: no output (clean parse)

- [ ] **Step 3: Verify help still works**

Run: `./javaenv help`
Expected: normal usage output

- [ ] **Step 4: Commit**

```bash
git add javaenv
git commit -m "feat: javaenv install <major> resolves latest version from Adoptium"
```

---

### Task 4: Update shim template to handle major-only `.javaversion`

**Files:**
- Modify: `javaenv:232-270` (shim template inside `cmd_reshim()`)

- [ ] **Step 1: Replace the shim template**

Replace the shim template (the content between `cat > "${shim_path}" <<'SHIM'` and `SHIM`) with:

```bash
    cat > "${shim_path}" <<'SHIM'
#!/usr/bin/env bash
# javaenv shim
set -euo pipefail

JAVAENV_JAVA_DIR="${HOME}/.local/share/java"

resolve_version() {
  local dir="$PWD"
  while [[ "${dir}" != "" ]]; do
    if [[ -f "${dir}/.javaversion" ]]; then
      cat "${dir}/.javaversion"
      return
    fi
    dir="${dir%/*}"
  done
  if [[ -f "${HOME}/.javaversion" ]]; then
    cat "${HOME}/.javaversion"
  fi
}

resolve_major_to_installed() {
  local major="$1"
  local best=""

  for dir in "${JAVAENV_JAVA_DIR}"/*/; do
    [[ -d "${dir}" ]] || continue
    local name
    name="$(basename "${dir}")"
    local ver="${name#"${name%%[0-9]*}"}"
    local dir_major="${ver%%.*}"
    if [[ "${dir_major}" != "${major}" ]]; then
      continue
    fi

    if [[ -z "${best}" ]]; then
      best="${name}"
      continue
    fi

    local IFS='.+'
    local -a cur_parts=(${ver})
    local -a best_ver="${best#"${best%%[0-9]*}"}"
    local -a best_parts=(${best_ver})
    IFS=' '

    local i
    for ((i = 0; i < ${#cur_parts[@]}; i++)); do
      local cur_seg="${cur_parts[$i]:-0}"
      local best_seg="${best_parts[$i]:-0}"
      if (( cur_seg > best_seg )); then
        best="${name}"
        break
      elif (( cur_seg < best_seg )); then
        break
      fi
    done
  done

  echo "${best}"
}

version="$(resolve_version)"
if [[ -z "${version}" ]]; then
  echo "javaenv: no .javaversion file found in directory hierarchy or ~/.javaversion" >&2
  exit 1
fi

version="$(echo "${version}" | tr -d '[:space:]')"

# If version has no dots, resolve to highest installed major match
if [[ "${version}" != *.* ]]; then
  resolved="$(resolve_major_to_installed "${version}")"
  if [[ -z "${resolved}" ]]; then
    echo "javaenv: no JDK ${version}.x installed. Run: javaenv install ${version}" >&2
    exit 1
  fi
  version="${resolved}"
fi

exe_name="$(basename "$0")"
exe_path="${JAVAENV_JAVA_DIR}/${version}/bin/${exe_name}"

if [[ ! -x "${exe_path}" ]]; then
  echo "javaenv: ${exe_name} not found for JDK ${version}" >&2
  echo "Run: javaenv install ${version}" >&2
  exit 1
fi

exec "${exe_path}" "$@"
SHIM
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n javaenv`
Expected: no output (clean parse)

- [ ] **Step 3: Commit**

```bash
git add javaenv
git commit -m "feat: shims resolve major-only .javaversion to highest installed match"
```

---

### Task 5: Update `cmd_current()`, `cmd_home()`, and `cmd_versions()` to handle major-only versions

**Files:**
- Modify: `javaenv` — `cmd_current()`, `cmd_home()`, `cmd_versions()`

- [ ] **Step 1: Update `cmd_current()` to resolve major-only versions**

Replace `cmd_current()` (lines 188-204) with:

```bash
cmd_current() {
  local version
  version="$(resolve_version)"

  if [[ -z "${version}" ]]; then
    echo "No Java version set. Create .javaversion or ~/.javaversion" >&2
    exit 1
  fi

  version="$(echo "${version}" | tr -d '[:space:]')"

  # Resolve major-only version to installed
  if [[ "${version}" != *.* ]]; then
    local resolved
    resolved="$(resolve_major_to_installed "${version}")"
    if [[ -z "${resolved}" ]]; then
      echo "No JDK ${version}.x installed. Run: javaenv install ${version}" >&2
      exit 1
    fi
    version="${resolved}"
  fi

  local dest="${JAVAENV_JAVA_DIR}/${version}"
  if [[ ! -d "${dest}" ]]; then
    echo "JDK ${version} is not installed. Run: javaenv install ${version}" >&2
    exit 1
  fi

  echo "${version}"
}
```

- [ ] **Step 2: Update `cmd_home()` to resolve major-only versions**

Replace `cmd_home()` (lines 206-216) with:

```bash
cmd_home() {
  local version
  version="$(resolve_version)"

  if [[ -z "${version}" ]]; then
    echo "No Java version set. Create .javaversion or ~/.javaversion" >&2
    exit 1
  fi

  version="$(echo "${version}" | tr -d '[:space:]')"

  # Resolve major-only version to installed
  if [[ "${version}" != *.* ]]; then
    local resolved
    resolved="$(resolve_major_to_installed "${version}")"
    if [[ -z "${resolved}" ]]; then
      echo "No JDK ${version}.x installed. Run: javaenv install ${version}" >&2
      exit 1
    fi
    version="${resolved}"
  fi

  echo "${JAVAENV_JAVA_DIR}/${version}"
}
```

- [ ] **Step 3: Update `cmd_versions()` to mark major-matched current version**

Replace `cmd_versions()` (lines 167-186) with:

```bash
cmd_versions() {
  if [[ ! -d "${JAVAENV_JAVA_DIR}" ]]; then
    echo "No JDK versions installed"
    return 0
  fi

  local current
  current="$(resolve_version | tr -d '[:space:]')"

  # Resolve major-only to installed for comparison
  if [[ -n "${current}" && "${current}" != *.* ]]; then
    current="$(resolve_major_to_installed "${current}")"
  fi

  for dir in "${JAVAENV_JAVA_DIR}"/*/; do
    [[ -d "${dir}" ]] || continue
    local v
    v="$(basename "${dir}")"
    if [[ "${v}" == "${current}" ]]; then
      echo "* ${v}"
    else
      echo "  ${v}"
    fi
  done
}
```

- [ ] **Step 4: Verify syntax**

Run: `bash -n javaenv`
Expected: no output (clean parse)

- [ ] **Step 5: Commit**

```bash
git add javaenv
git commit -m "feat: current/home/versions commands support major-only .javaversion"
```

---

### Task 6: Update help text and verify end-to-end

**Files:**
- Modify: `javaenv` — `usage()` function

- [ ] **Step 1: Update usage text**

Replace the `usage()` function with:

```bash
usage() {
  cat <<EOF
Usage: javaenv <command> [args]

Commands:
  install <version>     Install a JDK version (e.g., 21 or 21.0.7+6)
  install -l|--list     List available JDK versions from Adoptium
  uninstall <version>   Remove an installed JDK version
  versions              List installed JDK versions
  current               Show the currently active JDK version
  home                  Print JAVA_HOME for the current version
  reshim                Regenerate shims in ~/.local/bin
  help                  Show this help message

Version is resolved from .javaversion in the current directory
(searching up), falling back to ~/.javaversion.
A major version (e.g., 21) resolves to the latest installed patch.
EOF
}
```

- [ ] **Step 2: Verify help output**

Run: `./javaenv help`
Expected: updated help text showing `21 or 21.0.7+6` example and major version note

- [ ] **Step 3: Verify full syntax one final time**

Run: `bash -n javaenv`
Expected: no output (clean parse)

- [ ] **Step 4: Commit**

```bash
git add javaenv
git commit -m "docs: update help text for major version aliasing"
```
