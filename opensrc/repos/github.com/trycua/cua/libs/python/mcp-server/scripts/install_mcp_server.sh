#!/bin/bash

set -e

# Create the ~/.cua directory if it doesn't exist
mkdir -p "$HOME/.cua"

# Create start_mcp_server.sh script in ~/.cua directory
cat > "$HOME/.cua/start_mcp_server.sh" << 'EOF'
#!/bin/bash

set -e

# Function to check if a directory is writable
is_writable() {
    [ -w "$1" ]
}

# Function to check if a command exists (silent)
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Find a writable directory for the virtual environment
if is_writable "$HOME"; then
    VENV_DIR="$HOME/.cua-mcp-venv"
elif is_writable "/tmp"; then
    VENV_DIR="/tmp/.cua-mcp-venv"
else
    # Try to create a directory in the current working directory
    TEMP_DIR="$(pwd)/.cua-mcp-venv"
    if is_writable "$(pwd)"; then
        VENV_DIR="$TEMP_DIR"
    else
        echo "Error: Cannot find a writable directory for the virtual environment." >&2
        exit 1
    fi
fi

# Check if Python is installed
if ! command_exists python3; then
    echo "Error: Python 3 is not installed." >&2
    exit 1
fi

# Check if pip is installed
if ! command_exists pip3; then
    echo "Error: pip3 is not installed." >&2
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    # Redirect output to prevent JSON parsing errors in Claude
    python3 -m venv "$VENV_DIR" >/dev/null 2>&1
fi

# Activate virtual environment
source "$VENV_DIR/bin/activate"

# Always install/upgrade the latest version of cua-mcp-server
pip install --upgrade "cua-mcp-server"

# Run the MCP server with isolation from development paths
cd "$VENV_DIR"  # Change to venv directory to avoid current directory in path

python3 -c "from mcp_server.server import main; main()"
EOF

# Make the script executable
chmod +x "$HOME/.cua/start_mcp_server.sh"

echo "MCP server startup script created at $HOME/.cua/start_mcp_server.sh"
