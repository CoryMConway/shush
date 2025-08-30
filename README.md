# What is it?
Shush is a tool to help you manage your shell scripts. It builds a cli tool dynamically based off of the folder structure of a specified directory.

https://github.com/user-attachments/assets/dfc90725-5596-47f6-8e13-05f67abc0b09

# Installation
Make sure you have nodejs version 20.0.0 or above ([Download here](https://nodejs.org/en/download))
```bash
node -v
```

Then install with the below command
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/CoryMConway/shush/refs/heads/main/install_shush.sh)
```
<img width="1588" height="574" alt="image" src="https://github.com/user-attachments/assets/1425edd8-e3d2-4a83-b37b-e77cedc797bb" />


Now open a new terminal and run the "shush" command
```bash
shush
```

# Update shush to latest code
All you have to do is run this update command!
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/CoryMConway/shush/refs/heads/main/update_shush.sh)
```
<img width="1917" height="1034" alt="image" src="https://github.com/user-attachments/assets/da99f7ae-820a-462a-a05c-fdb48fe08440" />

# How it works
If you have specificed "$HOME/managed-repos" as your storage folder for your bash scripts, and you have a directory tree like below
```bash
managed-repos
    ├── Environment-Cleanup
    │   └── clean_test_qa_users.sh
    └── Web-Scraping
        └── Scrape_Stocks.sh
```
It will create a cli like so when you run "shush" in your terminal

<img width="1918" height="1045" alt="image" src="https://github.com/user-attachments/assets/4841bafb-897e-4a02-82ce-fe39020a4d60" />
# Bash Scripts
Bash scripts require a shebang line at the top of your file to specify the shell interpreter. Shush supports various shell setups across different platforms.

## Linux

### System Bash
```bash
#!/bin/bash
echo "Hello World"
```

### Portable Bash (recommended)
```bash
#!/usr/bin/env bash
echo "Hello World"
```

### Other Shells
```bash
#!/bin/sh
echo "Hello World"

#!/usr/bin/env zsh
echo "Hello World"

#!/usr/bin/env fish
echo "Hello World"
```

### NixOS
NixOS users can use nix-shell shebangs for declarative shell environments:

#### Option 1: Inline packages
```bash
#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq

curl -s "https://api.github.com/users/octocat" | jq '.name'
```

#### Option 2: With shell.nix (recommended)
Create a `shell.nix` file in your script's directory:
```nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    bash
    curl
    jq
  ];
}
```

Then use a simple shebang:
```bash
#!/usr/bin/env nix-shell
#!nix-shell -i bash

curl -s "https://api.github.com/users/octocat" | jq '.name'
```

## macOS

### System Bash (older versions)
```bash
#!/bin/bash
echo "Hello World"
```

### Homebrew Bash (recommended)
```bash
#!/opt/homebrew/bin/bash
# or if bash is in PATH:
#!/usr/bin/env bash
echo "Hello World"
```

### Zsh (default on macOS Catalina+)
```bash
#!/usr/bin/env zsh
echo "Hello World"
```

### Other Shells
```bash
#!/usr/bin/env fish
echo "Hello World"

# Homebrew-installed shells
#!/opt/homebrew/bin/fish
echo "Hello World"
```

## Universal Recommendations

### Most Portable (works everywhere)
```bash
#!/usr/bin/env bash
```

### POSIX Compliant (maximum compatibility)
```bash
#!/bin/sh
```

### Best Practices
- Use `#!/usr/bin/env bash` for maximum portability
- Use `#!/bin/bash` for systems where you know bash location
- Use `#!/bin/sh` for POSIX-compliant scripts
- Always test your shebang by running the script directly: `./myscript.sh`

## Notes
- The shebang tells the system which interpreter to use
- `#!/usr/bin/env` searches PATH for the interpreter (more portable)
- Direct paths like `#!/bin/bash` are faster but less portable
- NixOS nix-shell shebangs provide reproducible environments with specific tool versions

# Python Scripts
Python scripts require a shebang line at the top of your file to specify the interpreter. Shush supports various Python setups across different platforms and dependency managers.

## Linux

### System Python
```python
#!/usr/bin/env python3
print("Hello World")
```

### Virtual Environment (venv)
```bash
# Create and activate virtual environment
python3 -m venv myenv
source myenv/bin/activate
pip install requests beautifulsoup4
```

```python
#!/path/to/myenv/bin/python3
import requests
print("Hello World")
```

### Poetry
```bash
# In your project directory
poetry install
```

```python
#!/usr/bin/env poetry run python
import requests
print("Hello World")
```

### Pipenv
```bash
# In your project directory
pipenv install
```

```python
#!/usr/bin/env pipenv run python
import requests
print("Hello World")
```

### Conda/Miniconda
```bash
# Create and activate conda environment
conda create -n myenv python=3.11
conda activate myenv
conda install requests beautifulsoup4
```

```python
#!/path/to/conda/envs/myenv/bin/python
import requests
print("Hello World")
```

### NixOS
NixOS users can use nix-shell shebangs for declarative dependency management:

#### Option 1: Inline packages
```python
#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3 python3Packages.requests python3Packages.beautifulsoup4

import requests
print("Hello World")
```

#### Option 2: With shell.nix (recommended)
Create a `shell.nix` file in your script's directory:
```nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    python3
    python3Packages.requests
    python3Packages.beautifulsoup4
  ];
}
```

Then use a simple shebang:
```python
#!/usr/bin/env nix-shell
#!nix-shell -i python3

import requests
print("Hello World")
```

## macOS

### System Python (not recommended)
```python
#!/usr/bin/env python3
print("Hello World")
```

### Homebrew Python
```python
#!/usr/bin/env python3
# or
#!/opt/homebrew/bin/python3
print("Hello World")
```

### Virtual Environment (recommended)
```bash
# Create and activate virtual environment
python3 -m venv myenv
source myenv/bin/activate
pip install requests beautifulsoup4
```

```python
#!/path/to/myenv/bin/python3
import requests
print("Hello World")
```

### Poetry (recommended)
```bash
# In your project directory
poetry install
```

```python
#!/usr/bin/env poetry run python
import requests
print("Hello World")
```

### Conda (recommended)
```bash
# Install miniconda first, then:
conda create -n myenv python=3.11
conda activate myenv
conda install requests beautifulsoup4
```

```python
#!/path/to/conda/envs/myenv/bin/python
import requests
print("Hello World")
```

## Notes
- Use absolute paths in shebangs for virtual environments and conda environments
- The `#!/usr/bin/env` approach works when the interpreter is in your PATH
- NixOS nix-shell shebangs provide the most reproducible environment
- Always test your shebang by running the script directly: `./myscript.py`

# Next steps
- support python scripts
- support node.js scripts
