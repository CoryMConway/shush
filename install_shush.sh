#!/usr/bin/env bash
set -euo pipefail

# =========================
# shush Python Installer
# =========================

APP_DIR="$HOME/.shush"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/shush"
BIN_DIR="$HOME/.local/bin"
LAUNCHER="$BIN_DIR/shush"
APP_ENTRY="$APP_DIR/shush.py"

# ---- prereqs ----
command -v python3 >/dev/null 2>&1 || { echo "❌ Python3 not found. Install Python 3.7+"; exit 1; }

# Check Python version
PYTHON_VERSION=$(python3 -c "import sys; print('.'.join(map(str, sys.version_info[:2])))")
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 7 ]); then
    echo "❌ Python 3.7+ required. Found Python $PYTHON_VERSION"
    exit 1
fi

# ---- dirs ----
mkdir -p "$APP_DIR" "$BIN_DIR" "$CONF_DIR"

# ---- install dependency ----
echo "📦 Installing rich dependency..."
python3 -m pip install rich

# ---- app ----
cat > "$APP_ENTRY" <<'EOF'
#!/usr/bin/env python3

import os
import sys
import json
import subprocess
import stat
import pty as pty_module
import select
import termios
import tty
from pathlib import Path
from typing import Optional, Dict, Any, List, Tuple
from dataclasses import dataclass

try:
    from rich.console import Console
    from rich.panel import Panel
    from rich.text import Text
    from rich.live import Live
    from rich.layout import Layout
    from rich.align import Align
except ImportError:
    print("❌ Required dependency 'rich' not found. Please install with: pip install rich")
    sys.exit(1)


class KeyboardInput:
    """Handle keyboard input for arrow key navigation"""
    
    def __init__(self):
        self.old_settings = None
    
    def __enter__(self):
        if sys.stdin.isatty():
            self.old_settings = termios.tcgetattr(sys.stdin.fileno())
            tty.setraw(sys.stdin.fileno())
            # Hide cursor while navigating
            print("\033[?25l", end="", flush=True)
        return self
    
    def __exit__(self, type, value, traceback):
        if sys.stdin.isatty():
            # Show cursor when exiting
            print("\033[?25h", end="", flush=True)
            if self.old_settings:
                termios.tcsetattr(sys.stdin.fileno(), termios.TCSADRAIN, self.old_settings)
    
    def get_key(self):
        """Get a single keypress"""
        ch = sys.stdin.read(1)
        
        # Handle escape sequences (arrow keys)
        if ch == '\x1b':  # ESC
            seq = sys.stdin.read(2)
            if seq == '[A':
                return 'UP'
            elif seq == '[B':
                return 'DOWN' 
            elif seq == '[C':
                return 'RIGHT'
            elif seq == '[D':
                return 'LEFT'
            else:
                return 'ESC'
        elif ch == '\r' or ch == '\n':
            return 'ENTER'
        elif ch == '\x03':  # Ctrl+C
            return 'CTRL_C'
        elif ch == 'q' or ch == 'Q':
            return 'QUIT'
        elif ch == 'r' or ch == 'R':
            return 'CHANGE_ROOT'
        else:
            return ch


@dataclass
class ShebangInfo:
    has_shebang: bool
    type: str  # 'none', 'regular', 'nix-shell'
    has_shell_nix: bool = False
    script_dir: str = ""
    shebang_lines: List[str] = None

    def __post_init__(self):
        if self.shebang_lines is None:
            self.shebang_lines = []


class ConfigManager:
    def __init__(self):
        xdg_config = os.environ.get('XDG_CONFIG_HOME')
        if xdg_config:
            self.config_dir = Path(xdg_config) / 'shush'
        else:
            self.config_dir = Path.home() / '.config' / 'shush'
        self.config_path = self.config_dir / 'config.json'

    def read_config(self) -> Dict[str, Any]:
        try:
            if self.config_path.exists():
                return json.loads(self.config_path.read_text())
        except (json.JSONDecodeError, OSError):
            pass
        return {}

    def write_config(self, config: Dict[str, Any]):
        self.config_dir.mkdir(parents=True, exist_ok=True)
        self.config_path.write_text(json.dumps(config, indent=2))


class FileManager:
    @staticmethod
    def is_dir(path: str) -> bool:
        try:
            return Path(path).is_dir()
        except:
            return False

    @staticmethod
    def has_shebang(file_path: str) -> bool:
        try:
            content = Path(file_path).read_text()
            return content.startswith('#!')
        except:
            return False

    @staticmethod
    def get_shebang_info(file_path: str) -> ShebangInfo:
        try:
            content = Path(file_path).read_text()
            lines = content.split('\n')

            if not lines[0].startswith('#!'):
                return ShebangInfo(has_shebang=False, type='none')

            first_line = lines[0]
            second_line = lines[1] if len(lines) > 1 else ''

            # Check for nix-shell shebang
            if 'nix-shell' in first_line:
                has_shell_nix = ' -p ' not in second_line and second_line.startswith('#!nix-shell')
                return ShebangInfo(
                    has_shebang=True,
                    type='nix-shell',
                    has_shell_nix=has_shell_nix,
                    script_dir=str(Path(file_path).parent),
                    shebang_lines=[line for line in lines[:2] if line.startswith('#!')]
                )

            # Regular shebang
            return ShebangInfo(
                has_shebang=True,
                type='regular',
                shebang_lines=[first_line]
            )
        except:
            return ShebangInfo(has_shebang=False, type='none')

    @staticmethod
    def list_dir(cur_dir: str) -> List[Dict[str, str]]:
        try:
            path = Path(cur_dir)
            entries = [e for e in path.iterdir() if not e.name.startswith('.')]

            dirs = []
            shs = []
            pys = []

            for entry in entries:
                full_path = str(entry)
                if entry.is_dir():
                    dirs.append({'type': 'dir', 'name': entry.name, 'full': full_path})
                elif entry.is_file() and entry.suffix == '.sh':
                    shs.append({'type': 'sh', 'name': entry.name, 'full': full_path})
                elif entry.is_file() and entry.suffix == '.py':
                    pys.append({'type': 'py', 'name': entry.name, 'full': full_path})

            # Sort each category
            dirs.sort(key=lambda x: x['name'].lower())
            shs.sort(key=lambda x: x['name'].lower())
            pys.sort(key=lambda x: x['name'].lower())

            return dirs + shs + pys
        except:
            return []


class PTYRunner:
    def __init__(self):
        self.master_fd = None
        self.slave_fd = None
        self.process = None

    def run_script(self, command: str, args: List[str], cwd: Optional[str] = None) -> Tuple[int, str]:
        """Run script with PTY for interactive support"""
        try:
            # Create PTY
            self.master_fd, self.slave_fd = pty_module.openpty()

            # Set terminal to raw mode to handle interactive input
            old_settings = termios.tcgetattr(sys.stdin.fileno())
            tty.setraw(sys.stdin.fileno())

            output = ""
            
            try:
                # Spawn process
                self.process = subprocess.Popen(
                    [command] + args,
                    stdin=self.slave_fd,
                    stdout=self.slave_fd,
                    stderr=self.slave_fd,
                    cwd=cwd,
                    env={**os.environ, 'TERM': 'dumb', 'PYTHONUNBUFFERED': '1'},
                    preexec_fn=os.setsid
                )

                # Close slave end in parent
                os.close(self.slave_fd)
                self.slave_fd = None

                while True:
                    # Check if process is still running
                    if self.process.poll() is not None:
                        break

                    # Use select to handle both stdin and master_fd
                    ready, _, _ = select.select([sys.stdin, self.master_fd], [], [], 0.1)

                    for fd in ready:
                        if fd == sys.stdin:
                            # Forward user input to process
                            try:
                                data = os.read(sys.stdin.fileno(), 1024)
                                if data:
                                    os.write(self.master_fd, data)
                            except OSError:
                                break
                        elif fd == self.master_fd:
                            # Read process output
                            try:
                                data = os.read(self.master_fd, 1024)
                                if data:
                                    decoded = data.decode('utf-8', errors='replace')
                                    # Filter out problematic escape sequences
                                    filtered = self._filter_escape_sequences(decoded)
                                    output += filtered
                                    # Echo to terminal
                                    sys.stdout.write(filtered)
                                    sys.stdout.flush()
                            except OSError:
                                break

                return_code = self.process.wait()
                return return_code, output

            finally:
                # Restore terminal settings
                termios.tcsetattr(sys.stdin.fileno(), termios.TCSADRAIN, old_settings)

        except Exception as e:
            return -1, f"Error running script: {e}"
        finally:
            self._cleanup()

    def _filter_escape_sequences(self, data: str) -> str:
        """Filter out problematic escape sequences"""
        import re
        filtered = data
        # Remove cursor position responses
        filtered = re.sub(r'\x1b\[[0-9;]*R', '', filtered)
        filtered = re.sub(r'\[[0-9]+;[0-9]+R', '', filtered)
        # Remove private mode sequences
        filtered = re.sub(r'\x1b\[\?[0-9;]*[a-zA-Z]', '', filtered)
        # Remove device attribute responses
        filtered = re.sub(r'\x1b\[>[0-9;]*[a-zA-Z]', '', filtered)
        return filtered

    def _cleanup(self):
        """Clean up file descriptors and processes"""
        if self.master_fd:
            os.close(self.master_fd)
            self.master_fd = None
        if self.slave_fd:
            os.close(self.slave_fd)
            self.slave_fd = None
        if self.process:
            try:
                self.process.terminate()
                self.process.wait(timeout=5)
            except:
                try:
                    self.process.kill()
                    self.process.wait()
                except:
                    pass


class ShushApp:
    def __init__(self):
        self.console = Console()
        self.config_manager = ConfigManager()
        self.config = self.config_manager.read_config()
        self.root = self.config.get('root', '')
        self.current_dir = self.root
        self.selected_index = 0

    def run(self):
        """Main application loop"""
        if not self.root or not FileManager.is_dir(self.root):
            self.console.print("[red bold]Error: No valid root directory configured.[/red bold]")
            self.console.print("Please run the installer again.")
            return

        self.current_dir = self.root

        while True:
            try:
                self.show_menu()
            except KeyboardInterrupt:
                self.console.print("\n[yellow]Goodbye![/yellow]")
                break

    def show_menu(self):
        """Display the main menu with arrow key navigation"""
        # Get directory contents
        items = FileManager.list_dir(self.current_dir)
        
        # Build menu items
        menu_items = []

        # Directories
        for item in items:
            if item['type'] == 'dir':
                menu_items.append((f"📁 {item['name']}", 'dir', item['full']))

        # Scripts
        for item in items:
            if item['type'] == 'sh':
                menu_items.append((f"🐚 {item['name']}", 'sh', item['full']))
            elif item['type'] == 'py':
                menu_items.append((f"🐍 {item['name']}", 'py', item['full']))

        # Add parent directory if not at root
        if self.current_dir != self.root:
            menu_items.append(("⬆️  .. (up)", 'up', ''))

        # Control options
        if menu_items:
            menu_items.append(("─" * 30, 'divider', ''))

        menu_items.append(("📌 Change base directory", 'change_root', ''))
        menu_items.append(("🚪 Quit", 'quit', ''))

        # Ensure selected index is valid
        if self.selected_index >= len(menu_items):
            self.selected_index = len(menu_items) - 1
        elif self.selected_index < 0:
            self.selected_index = 0

        with KeyboardInput() as kb:
            while True:
                # Clear screen and reset cursor
                print("\033[2J\033[H", end="", flush=True)
                
                # Force console to recalculate size
                self.console.clear()
                
                # Header  
                self.console.print(Panel.fit("[bold]shush[/bold]", border_style="blue"))
                self.console.print(f"[dim]{self.current_dir}[/dim]\n")

                # Display menu items with selection highlight
                for i, (label, action_type, path) in enumerate(menu_items):
                    if label.startswith('─'):
                        self.console.print(f"  {label}")
                    else:
                        if i == self.selected_index:
                            # Highlight selected item
                            self.console.print(f"[bold blue]❯ {label}[/bold blue]")
                        else:
                            self.console.print(f"  {label}")

                self.console.print("\n[dim]Tips: ↑/↓ to navigate • Enter to select • R change base • Q to quit[/dim]")

                # Get user input
                key = kb.get_key()
                
                if key == 'UP':
                    self.selected_index = (self.selected_index - 1) % len(menu_items)
                    # Skip dividers when navigating up
                    while menu_items[self.selected_index][1] == 'divider':
                        self.selected_index = (self.selected_index - 1) % len(menu_items)
                        
                elif key == 'DOWN':
                    self.selected_index = (self.selected_index + 1) % len(menu_items)
                    # Skip dividers when navigating down
                    while menu_items[self.selected_index][1] == 'divider':
                        self.selected_index = (self.selected_index + 1) % len(menu_items)
                        
                elif key == 'ENTER':
                    label, action_type, path = menu_items[self.selected_index]
                    if action_type != 'divider':
                        self.handle_selection(action_type, path)
                        break
                        
                elif key == 'QUIT' or key == 'CTRL_C':
                    raise KeyboardInterrupt
                    
                elif key == 'CHANGE_ROOT':
                    self.change_root()
                    break

    def handle_selection(self, action_type: str, path: str):
        """Handle menu selection"""
        if action_type == 'dir':
            self.current_dir = path
            self.selected_index = 0  # Reset selection when changing directories
        elif action_type == 'up':
            self.current_dir = str(Path(self.current_dir).parent)
            self.selected_index = 0  # Reset selection when going up
        elif action_type in ['sh', 'py']:
            self.run_script(path)
        elif action_type == 'change_root':
            self.change_root()
        elif action_type == 'quit':
            raise KeyboardInterrupt
        elif action_type == 'divider':
            pass  # Do nothing for divider

    def run_script(self, file_path: str):
        """Run a script file"""
        self.console.clear()
        self.console.print(f"[yellow]Running: {Path(file_path).name}[/yellow]\n")

        script_info = FileManager.get_shebang_info(file_path)
        
        # Validate shebang
        if file_path.endswith('.py') and not script_info.has_shebang:
            self.show_error(
                file_path,
                "Python script missing shebang line. Add a shebang like #!/usr/bin/env python3 or use NixOS nix-shell format.",
                True
            )
            return

        if file_path.endswith('.sh') and not script_info.has_shebang:
            self.show_error(
                file_path,
                "Shell script missing shebang line. Add a shebang like #!/bin/bash or #!/usr/bin/env bash for better portability.",
                False
            )
            return

        # Make executable
        try:
            Path(file_path).chmod(Path(file_path).stat().st_mode | stat.S_IEXEC)
        except:
            pass

        # Prepare command
        if script_info.type == 'nix-shell':
            command = file_path
            args = []
            cwd = script_info.script_dir if script_info.has_shell_nix else None
        else:
            command = file_path
            args = []
            cwd = None

        # Run with PTY
        runner = PTYRunner()
        return_code, output = runner.run_script(command, args, cwd)

        # Show completion
        self.console.print(f"\n[green]✅ Script finished: {Path(file_path).name}[/green]")
        if return_code != 0:
            self.console.print(f"[red]Exit code: {return_code}[/red]")
        
        self.console.print("\nPress any key to return to menu...")
        with KeyboardInput() as kb:
            kb.get_key()

    def show_error(self, file_path: str, error_msg: str, is_python: bool):
        """Show error message with examples"""
        self.console.print(f"[red]❌ Error: {Path(file_path).name}[/red]")
        self.console.print(f"[red]{error_msg}[/red]\n")
        
        self.console.print("[dim]Examples:[/dim]")
        if is_python:
            self.console.print("[dim]  Regular: #!/usr/bin/env python3[/dim]")
            self.console.print("[dim]  NixOS:   #!/usr/bin/env nix-shell[/dim]")
            self.console.print("[dim]           #!nix-shell /full/path/shell.nix -i python3[/dim]")
            self.console.print("[dim]  Or same dir: #!nix-shell -i python3[/dim]")
            info_url = "https://github.com/CoryMConway/shush/blob/main/README.md#python-scripts"
        else:
            self.console.print("[dim]  Portable: #!/usr/bin/env bash[/dim]")
            self.console.print("[dim]  Direct:   #!/bin/bash[/dim]")
            self.console.print("[dim]  NixOS:    #!/usr/bin/env nix-shell[/dim]")
            self.console.print("[dim]            #!nix-shell /full/path/shell.nix -i bash[/dim]")
            self.console.print("[dim]  Or same dir: #!nix-shell -i bash[/dim]")
            info_url = "https://github.com/CoryMConway/shush/blob/main/README.md#bash-scripts"
        
        self.console.print(f"[blue]More Info: {info_url}[/blue]")
        self.console.print("\nPress any key to return to menu...")
        with KeyboardInput() as kb:
            kb.get_key()

    def change_root(self):
        """Change the root directory"""
        self.console.clear()
        self.console.print("[bold]Change base directory[/bold]\n")
        self.console.print(f"Current: {self.current_dir}")
        self.console.print("Enter new path (or press ESC to cancel):")
        
        # Simple text input - restore normal terminal mode temporarily
        try:
            old_settings = termios.tcgetattr(sys.stdin.fileno())
            termios.tcsetattr(sys.stdin.fileno(), termios.TCSADRAIN, old_settings)
            
            current_path = input(f"New path [{self.current_dir}]: ").strip()
            
            # Use default if empty
            if not current_path:
                current_path = self.current_dir
                
        except (EOFError, KeyboardInterrupt):
            return
        
        resolved_path = Path(current_path).expanduser().resolve()
        
        if not resolved_path.exists():
            self.console.print(f"[red]❌ Directory does not exist: {resolved_path}[/red]")
            self.console.print("Press any key to continue...")
            with KeyboardInput() as kb:
                kb.get_key()
            return
        
        if not resolved_path.is_dir():
            self.console.print("[red]❌ Path is not a directory[/red]")
            self.console.print("Press any key to continue...")
            with KeyboardInput() as kb:
                kb.get_key()
            return
        
        # Update configuration
        new_config = {**self.config, 'root': str(resolved_path)}
        self.config_manager.write_config(new_config)
        
        self.root = str(resolved_path)
        self.current_dir = self.root
        self.config = new_config
        self.selected_index = 0  # Reset selection
        
        self.console.print(f"[green]✅ Changed to: {resolved_path}[/green]")
        self.console.print("Press any key to continue...")
        with KeyboardInput() as kb:
            kb.get_key()


def main():
    """Entry point for the shush application"""
    app = ShushApp()
    app.run()


if __name__ == "__main__":
    main()
EOF

chmod +x "$APP_ENTRY"

# ---- launcher ----
cat > "$LAUNCHER" <<'EOF'
#!/usr/bin/env bash
# Launcher for Python shush
exec python3 "$HOME/.shush/shush.py" "$@"
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

echo "✅ Installed shush (Python version)"
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
