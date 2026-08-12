#!/bin/bash
# Set up a folder with its own SSH key and git identity.
#
# Usage:
#   setup-git-identity.sh [folder] [key-name] [email] [git-user-name]
#
# Example:
#   setup-git-identity.sh ~/personal personal me@example.com "Andrew Wu"
#
# Result:
#   - Creates the folder
#   - Generates ~/.ssh/id_ed25519_<key-name>
#   - Adds a Host alias "github-<key-name>" to ~/.ssh/config
#   - Writes ~/.gitconfig-<key-name> with the per-folder identity
#   - Appends an includeIf entry to ~/.gitconfig so the folder uses that config

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/init-lib.sh"

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
fi

FOLDER="$1"
KEY_NAME="$2"
EMAIL="$3"
GIT_NAME="$4"

[ -z "$FOLDER" ]   && read -r -p "Folder path (e.g., ~/personal): " FOLDER </dev/tty
[ -z "$KEY_NAME" ] && read -r -p "Key/host suffix (e.g., personal): " KEY_NAME </dev/tty
[ -z "$EMAIL" ]    && read -r -p "Email for SSH key and git commits: " EMAIL </dev/tty
[ -z "$GIT_NAME" ] && read -r -p "Git user.name for this folder: " GIT_NAME </dev/tty

if [ -z "$FOLDER" ] || [ -z "$KEY_NAME" ] || [ -z "$EMAIL" ] || [ -z "$GIT_NAME" ]; then
    echo "✗ Missing required input"
    exit 1
fi

# Expand ~ and resolve to absolute path
FOLDER="${FOLDER/#\~/$HOME}"
mkdir -p "$FOLDER"
FOLDER="$(cd "$FOLDER" && pwd)"
echo "✓ Folder ready: $FOLDER"

SSH_DIR="$HOME/.ssh"
SSH_KEY_PATH="$SSH_DIR/id_ed25519_$KEY_NAME"
SSH_CONFIG="$SSH_DIR/config"
GIT_CONFIG_PATH="$HOME/.gitconfig-$KEY_NAME"
HOST_ALIAS="github-$KEY_NAME"

mkdir -p "$SSH_DIR" && chmod 700 "$SSH_DIR"

# 1. Generate SSH key
if [ -f "$SSH_KEY_PATH" ]; then
    echo "✓ SSH key already exists: $SSH_KEY_PATH"
else
    ssh-keygen -t ed25519 -C "$EMAIL" -f "$SSH_KEY_PATH" -N ""
    echo "✓ SSH key generated: $SSH_KEY_PATH"
fi

# 2. Add to ssh-agent (Keychain-persisted on macOS)
eval "$(ssh-agent -s)" > /dev/null 2>&1
ssh_add_key "$SSH_KEY_PATH" || true
echo "✓ SSH key added to ssh-agent"

# 3. SSH host alias
touch "$SSH_CONFIG" && chmod 600 "$SSH_CONFIG"
if grep -q "^Host $HOST_ALIAS\$" "$SSH_CONFIG"; then
    echo "✓ SSH host alias already exists: $HOST_ALIAS"
else
    cat >> "$SSH_CONFIG" << EOF

Host $HOST_ALIAS
  HostName github.com
  User git
  IdentityFile $SSH_KEY_PATH
  IdentitiesOnly yes
  AddKeysToAgent yes
  UseKeychain yes
EOF
    echo "✓ SSH host alias added: $HOST_ALIAS"
fi

# 4. Per-folder git config
cat > "$GIT_CONFIG_PATH" << EOF
[user]
  email = $EMAIL
  name = $GIT_NAME
[core]
  sshCommand = "ssh -i $SSH_KEY_PATH -o IdentitiesOnly=yes"
[url "git@$HOST_ALIAS:"]
  insteadOf = git@github.com:
EOF
echo "✓ Per-folder git config written: $GIT_CONFIG_PATH"

# 5. includeIf in global gitconfig
GLOBAL_GITCONFIG="$HOME/.gitconfig"
INCLUDE_HEADER="[includeIf \"gitdir:$FOLDER/\"]"
if grep -qF "$INCLUDE_HEADER" "$GLOBAL_GITCONFIG" 2>/dev/null; then
    echo "✓ includeIf already present in ~/.gitconfig"
else
    cat >> "$GLOBAL_GITCONFIG" << EOF

$INCLUDE_HEADER
  path = $GIT_CONFIG_PATH
EOF
    echo "✓ includeIf appended to ~/.gitconfig"
fi

# 6. Copy public key to clipboard
PUB_KEY="$SSH_KEY_PATH.pub"
clip_copy < "$PUB_KEY"
echo ""
echo "✓ Public key copied to clipboard"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$PUB_KEY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 Next steps:"
echo "1. Add the key at https://github.com/settings/keys"
echo "2. Clone repos into $FOLDER. Both URL forms work:"
echo "     git clone git@github.com:owner/repo.git       (rewritten via insteadOf)"
echo "     git clone git@$HOST_ALIAS:owner/repo.git"
echo "3. Verify inside a repo under $FOLDER:"
echo "     git config user.email     # should be $EMAIL"
echo "     ssh -T git@$HOST_ALIAS    # should greet the right account"
