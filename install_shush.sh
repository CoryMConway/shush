#!/usr/bin/env bash
set -euo pipefail

# =========================
# shush Installer (Ink, NO JSX, uuid keys, pause-after-run)
# =========================

APP_DIR="$HOME/.shush"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/shush"
BIN_DIR="$HOME/.local/bin"
LAUNCHER="$BIN_DIR/shush"
APP_ENTRY="$APP_DIR/index.mjs"
PKG_JSON="$APP_DIR/package.json"

# ---- prereqs ----
command -v node >/dev/null 2>&1 || { echo "❌ Node.js not found. Install Node (v18+)"; exit 1; }
command -v npm  >/dev/null 2>&1 || { echo "❌ npm not found. Install npm"; exit 1; }

# ---- dirs ----
mkdir -p "$APP_DIR" "$BIN_DIR" "$CONF_DIR"

# ---- package.json ----
if [ ! -f "$PKG_JSON" ]; then
  cat > "$PKG_JSON" <<'JSON'
{
  "name": "shush",
  "private": true,
  "type": "module"
}
JSON
fi

# ---- deps ----
cd "$APP_DIR"
npm install --silent ink ink-select-input ink-text-input react uuid

# ---- app (no JSX) ----
cat > "$APP_ENTRY" <<'EOF'
import React, {useEffect, useMemo, useState} from 'react';
import {render, Text, Box, useApp, useStdout, useInput} from 'ink';
import SelectInput from 'ink-select-input';
import TextInput from 'ink-text-input';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {spawn} from 'node:child_process';
import {v4 as uuidv4} from 'uuid';

const h = React.createElement;

// --- config helpers ---
const confDir = process.env.XDG_CONFIG_HOME
  ? path.join(process.env.XDG_CONFIG_HOME, 'shush')
  : path.join(os.homedir(), '.config', 'shush');
const confPath = path.join(confDir, 'config.json');

function readConfig() {
  try { return JSON.parse(fs.readFileSync(confPath, 'utf8')); } catch { return {}; }
}
function writeConfig(cfg) {
  fs.mkdirSync(confDir, {recursive: true});
  fs.writeFileSync(confPath, JSON.stringify(cfg, null, 2));
}

function isDir(p) { try { return fs.statSync(p).isDirectory(); } catch { return false; } }
function hasShebang(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    return content.startsWith('#!');
  } catch {
    return false;
  }
}

function getShebangInfo(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n');
    
    if (!lines[0].startsWith('#!')) {
      return { hasShebang: false, type: 'none' };
    }
    
    const firstLine = lines[0];
    const secondLine = lines[1] || '';
    
    // Check for nix-shell shebang
    if (firstLine.includes('nix-shell')) {
      // Check if it's using a shell.nix file (no -p packages)
      const hasShellNix = !secondLine.includes(' -p ') && secondLine.startsWith('#!nix-shell');
      
      return { 
        hasShebang: true, 
        type: 'nix-shell',
        hasShellNix: hasShellNix,
        scriptDir: path.dirname(filePath),
        shebangLines: lines.slice(0, 2).filter(line => line.startsWith('#!'))
      };
    }
    
    // Regular shebang
    return { 
      hasShebang: true, 
      type: 'regular',
      shebangLines: [firstLine]
    };
  } catch {
    return { hasShebang: false, type: 'none' };
  }
}
function listDir(cur) {
  try {
    const entries = fs.readdirSync(cur, {withFileTypes: true}).filter(d => !d.name.startsWith('.'));
    const dirs = entries
      .filter(e => e.isDirectory())
      .map(e => ({type: 'dir', name: e.name, full: path.join(cur, e.name)}))
      .sort((a,b) => a.name.localeCompare(b.name));
    const shs = entries
      .filter(e => e.isFile() && e.name.endsWith('.sh'))
      .map(e => ({type: 'sh', name: e.name, full: path.join(cur, e.name)}))
      .sort((a,b) => a.name.localeCompare(b.name));
    const pys = entries
      .filter(e => e.isFile() && e.name.endsWith('.py'))
      .map(e => ({type: 'py', name: e.name, full: path.join(cur, e.name)}))
      .sort((a,b) => a.name.localeCompare(b.name));
    return [...dirs, ...shs, ...pys];
  } catch {
    return [];
  }
}

// --- views ---

function ChangeRoot({onCancel, onSet}) {
  const [val, setVal] = useState(process.cwd());
  const [err, setErr] = useState('');
  const submit = () => {
    const p = path.resolve(val);
    if (!isDir(p)) { setErr('That path is not a directory.'); return; }
    onSet(p);
  };
  useInput((_i, k) => { if (k.escape) onCancel(); });
  return h(Box, {flexDirection:'column'},
    h(Text, {bold:true}, 'Change base directory'),
    h(Box, {marginTop:1},
      h(Text, null, 'New path: '),
      h(TextInput, {value:val, onChange:setVal, onSubmit:submit})
    ),
    err ? h(Box, {marginTop:1}, h(Text, {color:'red'}, err)) : null,
    h(Box, {marginTop:1}, h(Text, {dimColor:true}, 'Enter to save • Esc to cancel'))
  );
}

function Header({curDir}) {
  return h(Box, {flexDirection:'column', marginBottom:1},
    h(Text, {bold:true}, 'shush'),
    h(Text, {dimColor:true}, curDir)
  );
}

function Menu({root, curDir, onDir, onUp, onRun, onChangeRoot, onQuit}) {
  const raw = useMemo(() => listDir(curDir), [curDir]);

  // Build items with guaranteed-unique keys using uuidv4
  const items = useMemo(() => {
    const arr = [];
    for (const it of raw)
      if (it.type === 'dir')
        arr.push({key: uuidv4(), label: `📁 ${it.name}`, value: {t:'dir', p: it.full}});
    for (const it of raw)
      if (it.type === 'sh')
        arr.push({key: uuidv4(), label: `🐚 ${it.name}`, value: {t:'sh', p: it.full}});
    for (const it of raw)
      if (it.type === 'py')
        arr.push({key: uuidv4(), label: `🐍 ${it.name}`, value: {t:'py', p: it.full}});
    if (curDir !== root)
      arr.push({key: uuidv4(), label: '⬆️  .. (up)', value: {t:'up'}});
    
    // Add divider if there are files/folders
    if (arr.length > 0) {
      arr.push({key: uuidv4(), label: '─'.repeat(30), value: {t:'divider'}});
    }
    
    arr.push({key: uuidv4(), label: '📌 Change base directory', value: {t:'setroot'}});
    arr.push({key: uuidv4(), label: '🚪 Quit', value: {t:'quit'}});
    return arr;
  }, [raw, curDir, root]);

  const onSelect = ({value}) => {
    if (value.t === 'dir') onDir(value.p);
    else if (value.t === 'sh') onRun(value.p);
    else if (value.t === 'py') onRun(value.p);
    else if (value.t === 'up') onUp();
    else if (value.t === 'setroot') onChangeRoot();
    else if (value.t === 'quit') onQuit();
    // Ignore divider selection
  };

  // ink-select-input uses item.key if present; passing itemKey is safe too
  return h(SelectInput, {items, onSelect, itemKey: 'key'});
}

function Running({file, onDone}) {
  const [output, setOutput] = useState('');
  const [finished, setFinished] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    const shebangInfo = getShebangInfo(file);
    
    // Check if Python file needs shebang
    if (file.endsWith('.py') && !shebangInfo.hasShebang) {
      setError('Python script missing shebang line. Add a shebang like #!/usr/bin/env python3 or use NixOS nix-shell format.');
      setFinished(true);
      return;
    }

    // Check if shell script needs shebang
    if (file.endsWith('.sh') && !shebangInfo.hasShebang) {
      setError('Shell script missing shebang line. Add a shebang like #!/bin/bash or #!/usr/bin/env bash for better portability.');
      setFinished(true);
      return;
    }

    try { fs.chmodSync(file, 0o755); } catch {}
    
    let command, args;
    
    if (shebangInfo.type === 'nix-shell') {
      // For nix-shell shebangs, execute from the script's directory
      command = file;
      args = [];
      // Change to script directory if using shell.nix
      if (shebangInfo.hasShellNix) {
        process.chdir(shebangInfo.scriptDir);
      }
    } else if (file.endsWith('.py')) {
      // Regular Python file with shebang
      command = file;
      args = [];
    } else if (file.endsWith('.sh')) {
      // Shell scripts with shebang
      command = file;
      args = [];
    } else {
      // Fallback (shouldn't happen with shebang checks)
      command = 'bash';
      args = [file];
    }
    
    const child = spawn(command, args, {stdio: 'pipe'});
    
    child.stdout.on('data', (data) => {
      setOutput(prev => prev + data.toString());
    });
    
    child.stderr.on('data', (data) => {
      setOutput(prev => prev + data.toString());
    });
    
    child.on('exit', (code) => {
      setFinished(true);
    });
  }, [file]);

  useInput((input, key) => {
    if (finished && (key.return || input === '\n')) {
      onDone();
    }
  });

  if (finished) {
    if (error) {
      const isPython = file.endsWith('.py');
      const isShell = file.endsWith('.sh');
      
      return h(Box, {flexDirection:'column'},
        h(Text, {color: 'red'}, `❌ Error: ${file}`),
        h(Text, {color: 'red'}, error),
        h(Text, {dimColor:true}, 'Examples:'),
        isPython && h(Text, {dimColor:true}, '  Regular: #!/usr/bin/env python3'),
        isPython && h(Text, {dimColor:true}, '  NixOS:   #!/usr/bin/env nix-shell'),
        isPython && h(Text, {dimColor:true}, '           #!nix-shell /full/path/shell.nix -i python3'),
        isPython && h(Text, {dimColor:true}, '  Or same dir: #!nix-shell -i python3'),
        isShell && h(Text, {dimColor:true}, '  Portable: #!/usr/bin/env bash'),
        isShell && h(Text, {dimColor:true}, '  Direct:   #!/bin/bash'),
        isShell && h(Text, {dimColor:true}, '  NixOS:    #!/usr/bin/env nix-shell'),
        isShell && h(Text, {dimColor:true}, '            #!nix-shell /full/path/shell.nix -i bash'),
        isShell && h(Text, {dimColor:true}, '  Or same dir: #!nix-shell -i bash'),
        h(Text, {color: 'blue'}, isPython 
          ? 'More Info: https://github.com/CoryMConway/shush/blob/main/README.md#python-scripts'
          : 'More Info: https://github.com/CoryMConway/shush/blob/main/README.md#bash-scripts'),
        h(Text, {dimColor:true}, '\nPress Enter to return to menu...')
      );
    }
    
    return h(Box, {flexDirection:'column'},
      h(Text, {color: 'green'}, `✅ Script finished: ${file}`),
      output && h(Text, null, '\n│ ' + output.trim().split('\n').join('\n│ ')),
      h(Text, {dimColor:true}, '\nPress Enter to return to menu...')
    );
  }

  return h(Box, {flexDirection:'column'},
    h(Text, {color: 'yellow'}, `Running: ${file}`),
    output && h(Text, null, '\n│ ' + output.trim().split('\n').join('\n│ ')),
    h(Text, {dimColor:true}, '\n(Ctrl+C to stop)')
  );
}

function App() {
  const {exit} = useApp();
  const [cfg] = useState(() => readConfig());
  const [root] = useState(() => cfg.root || '');
  const [curDir, setCurDir] = useState(() => root);
  const [mode, setMode] = useState('menu'); // 'change' | 'run' | 'menu'
  const [runFile, setRunFile] = useState('');

  if (!root || !isDir(root)) {
    return h(Box, {flexDirection:'column'},
      h(Text, {color:'red', bold:true}, 'Error: No valid root directory configured.'),
      h(Text, null, 'Please run the installer again.')
    );
  }

  const onDir   = (p) => setCurDir(p);
  const onUp    = () => setCurDir(path.dirname(curDir));
  const onRun   = (p) => { setRunFile(p); setMode('run'); };
  const onCR    = () => setMode('change');
  const onQuit  = () => exit();
  const onSet   = (p) => { 
    const newCfg = {...cfg, root: p};
    writeConfig(newCfg);
    setCurDir(p); 
    setMode('menu'); 
  };
  const onCancel= () => setMode('menu');
  const onDone  = () => setMode('menu');

  useInput((input, key) => { if (key.ctrl && input === 'r' && mode === 'menu') setMode('change'); });

  if (mode === 'change') return h(ChangeRoot, {onCancel, onSet});
  if (mode === 'run')    return h(Running, {file: runFile, onDone});

  return h(Box, {flexDirection:'column'},
    h(Header, {curDir}),
    h(Menu, {root, curDir, onDir, onUp, onRun, onChangeRoot: onCR, onQuit}),
    h(Box, {marginTop:1}, h(Text, {dimColor:true}, 'Tips: ↑/↓ to move • Enter to select • Ctrl+R change base'))
  );
}

render(h(App));
EOF

# ---- launcher (portable; no env var in shebang) ----
cat > "$LAUNCHER" <<'EOF'
#!/usr/bin/env bash
# Portable launcher: avoids shebang env var expansion issues.
NODE_PATH="$HOME/.shush/node_modules" exec node "$HOME/.shush/index.mjs" "$@"
EOF
chmod +x "$LAUNCHER"

# ---- setup root directory ----
echo
echo "🔧 Setting up shush..."
echo "Enter the directory where your shell scripts are stored:"
read -r -p "Path: " SCRIPT_ROOT

# Expand environment variables and resolve path
SCRIPT_ROOT=$(eval echo "$SCRIPT_ROOT")
SCRIPT_ROOT=$(realpath "$SCRIPT_ROOT" 2>/dev/null || echo "$SCRIPT_ROOT")
if [ ! -d "$SCRIPT_ROOT" ]; then
  echo "❌ Directory does not exist: $SCRIPT_ROOT"
  echo "Please create it first or choose an existing directory."
  exit 1
fi

# Write config
cat > "$CONF_DIR/config.json" <<JSON
{
  "root": "$SCRIPT_ROOT"
}
JSON

echo "✅ Installed shush"
echo "• Launcher : $LAUNCHER"
echo "• App file : $APP_ENTRY"
echo "• Config   : $CONF_DIR/config.json"
echo "• Scripts  : $SCRIPT_ROOT"
echo

# ---- PATH setup ----
case ":$PATH:" in
  *":$BIN_DIR:"*) 
    echo "✅ $BIN_DIR is already in your PATH"
    ;;
  *) 
    echo "🔧 Adding $BIN_DIR to your PATH..."
    
    # Detect shell and set appropriate rc file
    SHELL_RC=""
    if [ -n "${ZSH_VERSION:-}" ]; then
      SHELL_RC="$HOME/.zshrc"
    elif [ -n "${BASH_VERSION:-}" ]; then
      SHELL_RC="$HOME/.bashrc"
    else
      # Try to detect from SHELL environment variable
      case "$SHELL" in
        */zsh) SHELL_RC="$HOME/.zshrc" ;;
        */bash) SHELL_RC="$HOME/.bashrc" ;;
        *) SHELL_RC="" ;;
      esac
    fi
    
    if [ -n "$SHELL_RC" ]; then
      # Check if export line already exists
      if ! grep -q "export PATH.*$BIN_DIR" "$SHELL_RC" 2>/dev/null; then
        echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$SHELL_RC"
        echo "✅ Added to PATH in $SHELL_RC"
        echo "ℹ️  Restart your shell or run: source $SHELL_RC"
      else
        echo "✅ PATH already configured in $SHELL_RC"
      fi
    else
      echo "⚠️  Unable to determine your shell type (bash/zsh)"
      echo "   Please add this to your shell's rc file and restart:"
      echo "   export PATH=\"$BIN_DIR:\$PATH\""
    fi
    ;;
esac

echo
echo "Run: shush"

