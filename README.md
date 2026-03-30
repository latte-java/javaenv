# javaenv
Java environment scripts to install and use different versions of Java similar to rbenv

## Install

```bash
curl -fsSL https://lattejava.org/javaenv/install | bash
```

## Usage

```bash
# Install the latest JDK 21
javaenv install 21

# Install a specific version
javaenv install 21.0.7+6

# List available versions from Adoptium
javaenv install --list

# Set the global Java version
javaenv global 21

# Set the local Java version for the current directory
javaenv local 21

# Set Java version for the current shell session (requires javaenv init)
javaenv shell 21

# Clear the shell version override
javaenv shell --unset

# Show the currently active version
javaenv current

# List installed versions
javaenv versions

# Print JAVA_HOME for the current version
javaenv home

# Remove an installed version
javaenv uninstall 21.0.7+6
```

## Version Resolution

javaenv resolves the Java version using this precedence:

1. `JAVAENV_VERSION` env var (set by `javaenv shell`)
2. `.javaversion` file in the current directory (searching up the tree)
3. `~/.javaversion` (set by `javaenv global`)

The file can contain a full version (`21.0.7+6`) or just a major version (`21`). A major version resolves to the highest installed patch for that major.

## JAVA_HOME

To set `JAVA_HOME` automatically and enable `javaenv shell`, add one of the following to your shell init file:

**bash** (`~/.bashrc`):
```bash
eval "$(javaenv init)"
```

**zsh** (`~/.zshrc`):
```zsh
eval "$(javaenv init)"
```

**fish** (`~/.config/fish/config.fish` or Oh My Fish `init.fish`):
```fish
javaenv init | source
```
