#!/bin/bash

#check if following package is installed: jq, gh, curl, git, stow, if not run install script
packages=("jq" "gh" "curl" "git" "stow" "nvm" "zoxide" "nvim" "tmux")

credentials='{
    "credentials": [
        {
            "service_name": "jenkins.morrison.express",
            "variable_name": "JENKINS_TOKEN",
            "description": "Jenkins CI/CD Access Token, you can generate one from site provided below: \\e]8;;https://jenkins.morrison.express/\\e\\\\https://jenkins.morrison.express/\\e]8;;\\e\\\\"
        },
        {
            "service_name": "morrisonexpress.atlassian.net",
            "variable_name": "JIRA_TOKEN",
            "description": "Atlassian API Token (email:token), you can get your token from site provided below: \\e]8;;https://id.atlassian.com/manage-profile/security/api-tokens\\e\\\\https://id.atlassian.com/manage-profile/security/api-tokens\\e]8;;\\e\\\\"
        },
        {
            "service_name": "getdata.morrison.express",
            "variable_name": "GETDATATOKEN",
            "description": "GetData API Token, you can get it from site provided below: \\e]8;;https://morrisonexpress.atlassian.net/wiki/spaces/MOP/pages/2976415908/Project+Introduction\\e\\\\https://morrisonexpress.atlassian.net/wiki/spaces/MOP/pages/2976415908/Project+Introduction\\e]8;;\\e\\\\"
        }
    ]
}'

function install_package() {
    echo ""
    echo "=== Package Install Script ==="
    echo ""
    for pkg in "${packages[@]}"; do
        # Special handling for nvm since it's a shell function, not a binary
        if [ "$pkg" = "nvm" ]; then
            # Source nvm if it exists
            if [ -s "$HOME/.nvm/nvm.sh" ]; then
                source "$HOME/.nvm/nvm.sh"
            fi
            
            # Check if nvm is now available as a function
            if ! type nvm &> /dev/null; then
                echo "Cannot find package: $pkg, prepare to install..."
                echo "Installing nvm..."
                curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
                # Source nvm after installation
                export NVM_DIR="$HOME/.nvm"
                [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
            else
                echo "✓ nvm is already installed"
            fi
        else
            # Regular package check
            if ! command -v $pkg &> /dev/null; then
                echo "Cannot find package: $pkg, prepare to install..."
                brew install $pkg -y
            else
                echo "✓ $pkg is already installed"
            fi
        fi
    done
    echo "✓ package install complete"
}

function install_oh_my_zsh() {
    echo ""
    echo "=== Oh My Zsh Setup Script ==="
    echo ""
    # Check if oh-my-zsh is already installed
    if [ -d "$HOME/.oh-my-zsh" ]; then
        echo "✓ oh-my-zsh is already installed"
    else
        echo "Cannot find oh-my-zsh, prepare to install..."
        echo "Installing oh-my-zsh..."
        # Use unattended installation to avoid it taking over the terminal
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        
        if [ -d "$HOME/.oh-my-zsh" ]; then
            echo "✓ oh-my-zsh installed successfully"
        else
            echo "✗ Failed to install oh-my-zsh"
        fi
    fi
}

function check_and_fix_paths() {
    echo ""
    echo "=== Path Configuration Check ==="
    echo ""
    
    DOTFILE_ZSHRC="../zsh/.zshrc"
    
    # Check if dotfile zshrc exists
    if [ ! -f "$DOTFILE_ZSHRC" ]; then
        echo "⚠️  Warning: Dotfile zshrc not found at $DOTFILE_ZSHRC"
        return
    fi
    
    # Array to track issues found
    declare -a path_issues=()
    declare -a updated_paths=()
    
    # Extract paths from dotfile zshrc
    echo "Checking path configurations..."
    
    # Check project paths
    while IFS= read -r line; do
        if [[ $line =~ export[[:space:]]+(MOP[A-Z_]*PATH)=\"([^\"]+)\" ]]; then
            var_name="${BASH_REMATCH[1]}"
            var_value="${BASH_REMATCH[2]}"
            
            # Expand $HOME in the path
            expanded_path="${var_value/\$HOME/$HOME}"
            
            # Display current variable and ask if modification is needed
            echo ""
            echo "Found: $var_name=$var_value"
            read -p "Does this path need to be modified? Press n if none of repos are cloned yet (y/n): " modify_choice </dev/tty
            
            if [[ "$modify_choice" =~ ^[Yy]$ ]]; then
                read -p "Enter new path (use \$HOME for home directory): " new_path </dev/tty
                if [ -n "$new_path" ]; then
                    # Update in the dotfile zshrc
                    sed -i '' "s|export $var_name=\".*\"|export $var_name=\"$new_path\"|" "$DOTFILE_ZSHRC"
                    echo "✓ Updated $var_name to $new_path in dotfile config"
                    # Update var_value and expanded_path for the existence check
                    var_value="$new_path"
                    expanded_path="${new_path/\$HOME/$HOME}"
                    echo "New expanded path: $expanded_path"
                    updated_paths+=("$var_name")
                fi
            fi
            
            # Check if the path exists (using the potentially updated path)
            if [ ! -e "$expanded_path" ]; then
                echo "⚠️  Path does not exist: $expanded_path"
                mkdir -p "$expanded_path"
                if [ $? -eq 0 ]; then
                    echo "✓ Directory created: $expanded_path"
                else
                    echo "✗ Failed to create directory: $expanded_path"
                    path_issues+=("$var_name=$var_value (Failed to create: $expanded_path)")
                fi
            else
                echo "✓ Path exists: $expanded_path"
            fi
        fi
    done < <(grep -E "^export MOP[A-Z_]*PATH=" "$DOTFILE_ZSHRC")
    
    # Report findings
    if [ ${#path_issues[@]} -eq 0 ]; then
        echo ""
        echo "✓ All configured paths exist"
    else
        echo ""
        echo "Found ${#path_issues[@]} path issue(s):"
        for issue in "${path_issues[@]}"; do
            echo "  ⚠️  $issue"
        done
        
        echo ""
        read -p "Would you like to review all your path settings again? (y/n): " fix_choice </dev/tty
        
        if [[ "$fix_choice" =~ ^[Yy]$ ]]; then
            check_and_fix_paths
            return
        fi
    fi
    
    # If any paths were updated, notify user
    if [ ${#updated_paths[@]} -gt 0 ]; then
        echo ""
        echo "⚠️  Paths were updated. Environment variables will be reloaded."
    fi
    
    echo ""
    echo "✓ Path Check Complete"
}

function handle_credentials() {
    echo ""
    echo "=== Credentials Setup Script ==="
    echo ""
    
    # Parse credentials from JSON config
    cred_count=$(echo "$credentials" | jq -r '.credentials | length')
    
    # Process each credential
    for ((i=0; i<$cred_count; i++)); do
        service_name=$(echo "$credentials" | jq -r ".credentials[$i].service_name")
        variable_name=$(echo "$credentials" | jq -r ".credentials[$i].variable_name")
        description=$(echo "$credentials" | jq -r ".credentials[$i].description")
        
        echo ""
        printf "Setting up: %b \n" "$description"
        
        # Check if credential already exists in keychain
        existing=$(security find-generic-password -a "$USER" -s "$service_name" -w 2>/dev/null)
        
        if [ -n "$existing" ]; then
            read -p "Credential already exists for $service_name. Update? (y/n): " update_choice
            if [[ ! "$update_choice" =~ ^[Yy]$ ]]; then
                echo "Skipping $service_name"
                continue
            fi
        fi
        
        # Prompt for credential (display description without escape sequences for the prompt)
        description_plain=$(echo "$credentials" | jq -r ".credentials[$i].description" | sed 's/\\e\]8;;[^\\]*\\e\\\\//g; s/\\e\]8;;\\e\\\\//g')
        read -p "Enter your $description_plain: " credential_value
        
        if [ -z "$credential_value" ]; then
            echo "⚠️  Warning: Empty value provided, skipping $service_name"
            continue
        fi
        
        # Store credential in macOS Keychain
        echo "Storing credential in macOS Keychain..."
        security add-generic-password -a "$USER" -s "$service_name" -w "$credential_value" -U
        
        if [ $? -eq 0 ]; then
            echo "✓ Credential stored successfully in Keychain"
        else
            echo "✗ Failed to store credential in Keychain"
        fi
    done
    
    echo ""
    echo "✓ Credentials Setup Complete"
    echo "⚠️  Note: Credentials are stored in macOS Keychain and will be loaded from .zshrc"
}

#function handle_git_clone: clone project to path defined in .zshrc
function handle_git_clone() {
    echo ""
    echo "=== Git Repository Clone Script ==="
    echo ""
    
    # Construct git_project JSON with current environment variables
    # This is done here (after sourcing .zshrc) so variables have actual values
    git_project='{
        "projects": [
            {"name": "MorrisonExpress/mop_console", "path": "'"$MOP_CONSOLE_PATH"'"},
            {"name": "MorrisonExpress/mop_configuration_files", "path": "'"$MOP_CONFIGURATION_PATH"'"},
            {"name": "MorrisonExpress/mop-console-monorepo", "path": "'"$MOP_MONOREPO_PATH"'"},
            {"name": "MorrisonExpress/mop_epod", "path": "'"$MOP_EPOD_PATH"'"}
        ]
    }'
    
    # Check GitHub CLI authentication status
    echo "Verifying GitHub authentication..."
    gh auth status 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "✗ GitHub CLI is not authenticated"
        echo "⚠️  Please ensure 'setup_github_cli' ran successfully before this step"
        return 1
    fi
    
    echo "✓ GitHub authentication verified"
    echo ""
    
    # Parse the number of projects from JSON
    project_count=$(echo "$git_project" | jq -r '.projects | length')
    
    # Process each project
    for ((i=0; i<$project_count; i++)); do
        repo_name=$(echo "$git_project" | jq -r ".projects[$i].name")
        repo_path=$(echo "$git_project" | jq -r ".projects[$i].path")
        
        # Expand $HOME in the path
        expanded_path="${repo_path/\$HOME/$HOME}"
        
        echo "Checking repository: $repo_name"
        echo "Target path: $expanded_path"
        
        # Check if repository already exists
        if [ -d "$expanded_path/.git" ]; then
            echo "✓ Repository '$repo_name' already exists at $expanded_path"
            echo ""
            continue
        fi
        
        # Check if directory exists but is not a git repo
        if [ -d "$expanded_path" ] && [ ! -d "$expanded_path/.git" ]; then
            echo "⚠️  Directory exists but is not a git repository: $expanded_path"
            read -p "Do you want to remove it and clone fresh? (y/n): " remove_choice </dev/tty
            
            if [[ "$remove_choice" =~ ^[Yy]$ ]]; then
                rm -rf "$expanded_path"
                echo "✓ Removed existing directory"
            else
                echo "Skipping $repo_name"
                echo ""
                continue
            fi
        fi
        
        # Create parent directory if it doesn't exist
        parent_dir=$(dirname "$expanded_path")
        if [ ! -d "$parent_dir" ]; then
            echo "Creating parent directory: $parent_dir"
            mkdir -p "$parent_dir"
        fi
        
        # Clone the repository
        echo "Cloning repository '$repo_name'..."
        gh repo clone "$repo_name" "$expanded_path"
        
        if [ $? -eq 0 ]; then
            echo "✓ Successfully cloned $repo_name"
        else
            echo "✗ Failed to clone $repo_name"
        fi
        echo ""
    done
    
    echo "✓ Git Repository Clone Complete"
}
function stow_config() {
    echo ""
    echo "=== Stowing Configuration ==="
    echo ""
    
    # Save current directory
    CURRENT_DIR=$(pwd)
    
    cd ..
    stow zsh
    
    #check if $HOME/bin exists, if not create it
    if [ ! -d "$HOME/bin" ]; then
        mkdir "$HOME/bin"
        echo "Created $HOME/bin directory"
    fi
    stow --target=$HOME/bin bin
    stow nvim-stow
    stow opencode
    stow tmux
    stow starship
    stow wezterm
    
    # Return to original directory
    cd "$CURRENT_DIR"
    
    echo "✓ Stowing complete"
}

function load_environment_variables() {
    # Load environment variables from .zshrc without initializing oh-my-zsh
    # Extract only the export statements for MOP paths
    echo ""
    echo "=== Loading Environment Variables ==="
    if [ -f "$HOME/.zshrc" ]; then
        # Extract and evaluate only MOP_*_PATH exports
        while IFS= read -r line; do
            if [[ $line =~ ^export[[:space:]]+(MOP[A-Z_]*PATH)= ]]; then
                eval "$line"
                echo "✓ Loaded: ${BASH_REMATCH[1]}"
            fi
        done < <(grep -E "^export MOP[A-Z_]*PATH=" "$HOME/.zshrc")
        echo "✓ Environment variables loaded"
    else
        echo "⚠️  Warning: ~/.zshrc not found, environment variables may not be available"
    fi
}

function setup_ssh_key() {
    echo ""
    echo "=== SSH Key Setup for Git ==="
    echo ""
    
    SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
    SSH_CONFIG="$HOME/.ssh/config"
    
    # Ensure .ssh directory exists
    if [ ! -d "$HOME/.ssh" ]; then
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        echo "✓ Created .ssh directory"
    fi
    
    # Check if SSH key already exists
    if [ -f "$SSH_KEY_PATH" ]; then
        echo "✓ SSH key already exists at $SSH_KEY_PATH"
    else
        echo "No SSH key found. Generating new SSH key..."
        
        # Get email for SSH key
        read -p "Enter your email address for SSH key: " email </dev/tty
        
        if [ -z "$email" ]; then
            echo "✗ Email is required for SSH key generation"
            return 1
        fi
        
        # Generate SSH key
        ssh-keygen -t ed25519 -C "$email" -f "$SSH_KEY_PATH" -N ""
        
        if [ $? -eq 0 ]; then
            echo "✓ SSH key generated successfully"
        else
            echo "✗ Failed to generate SSH key"
            return 1
        fi
    fi
    
    # Start ssh-agent and add key
    echo "Starting ssh-agent and adding key..."
    eval "$(ssh-agent -s)" > /dev/null 2>&1
    ssh-add --apple-use-keychain "$SSH_KEY_PATH" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✓ SSH key added to ssh-agent"
    fi
    
    # Configure SSH config for automatic keychain usage
    if [ ! -f "$SSH_CONFIG" ] || ! grep -q "UseKeychain yes" "$SSH_CONFIG"; then
        echo "Configuring SSH config..."
        cat >> "$SSH_CONFIG" << 'EOF'

# SSH Key Configuration for Git
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519

Host *
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF
        chmod 600 "$SSH_CONFIG"
        echo "✓ Updated SSH config"
    else
        echo "✓ SSH config already configured"
    fi
    
    # Copy public key to clipboard
    if [ -f "$SSH_KEY_PATH.pub" ]; then
        cat "$SSH_KEY_PATH.pub" | pbcopy
        echo ""
        echo "✓ Public SSH key copied to clipboard"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Your public key:"
        cat "$SSH_KEY_PATH.pub"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "📝 Next steps:"
        echo "1. Go to GitHub: https://github.com/settings/keys"
        echo "2. Click 'New SSH key'"
        echo "3. Paste the key (already in your clipboard)"
        echo "4. Give it a title and save"
        echo ""
        read -p "Press Enter after you've added the key to GitHub..." </dev/tty
    fi
    
    # Test SSH connection to GitHub
    echo ""
    echo "Testing SSH connection to GitHub..."
    ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"
    
    if [ $? -eq 0 ]; then
        echo "✓ SSH connection to GitHub successful!"
    else
        echo "⚠️  SSH connection test completed (authentication may require key to be added to GitHub)"
    fi
    
    # Configure git to use SSH instead of HTTPS
    echo ""
    echo "Configuring git to use SSH for GitHub..."
    git config --global url."git@github.com:".insteadOf "https://github.com/"
    echo "✓ Git configured to use SSH for GitHub URLs"
    
    echo ""
    echo "✓ SSH Setup Complete"
}

function setup_github_cli() {
    echo ""
    echo "=== GitHub CLI Authentication ==="
    echo ""
    
    # Check if already authenticated
    gh auth status 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✓ GitHub CLI already authenticated"
        return 0
    fi
    
    echo "Authenticating GitHub CLI with SSH..."
    echo ""
    echo "You have two options:"
    echo "1. Browser-based authentication (default)"
    echo "2. Paste authentication token manually"
    echo ""
    read -p "Choose method (1 or 2) [1]: " auth_method </dev/tty
    auth_method=${auth_method:-1}
    
    if [ "$auth_method" = "2" ]; then
        # Token-based authentication
        echo ""
        echo "To get a token:"
        echo "1. Go to: https://github.com/settings/tokens/new"
        echo "2. Give it a name and select scopes: repo, read:org, workflow"
        echo "3. Generate and copy the token"
        echo ""
        read -p "Paste your GitHub token: " github_token </dev/tty
        
        if [ -z "$github_token" ]; then
            echo "✗ No token provided"
            return 1
        fi
        
        echo "$github_token" | gh auth login -p ssh -h github.com --with-token
    else
        # Browser-based authentication
        echo "This will open your browser for authentication."
        echo "⚠️  If you get stuck on the one-time code screen:"
        echo "   1. Copy the code shown"
        echo "   2. Press Enter in the browser prompt"
        echo "   3. Paste the code in the GitHub page"
        echo ""
        read -p "Press Enter to continue..." </dev/tty
        
        # Use SSH protocol for authentication with stdin from terminal
        gh auth login -p ssh -h github.com -w < /dev/tty
    fi
    
    # Verify authentication
    gh auth status 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✓ GitHub CLI authentication successful"
        return 0
    else
        echo "✗ GitHub CLI authentication failed"
        echo ""
        echo "Troubleshooting tips:"
        echo "1. Make sure you completed the browser authentication"
        echo "2. Try running manually: gh auth login -p ssh -h github.com -w"
        echo "3. Or use token method: gh auth login -p ssh -h github.com --with-token"
        return 1
    fi
}

install_package
install_oh_my_zsh
stow_config
check_and_fix_paths
load_environment_variables
handle_credentials
load_environment_variables  # Reload after credentials in case .zshrc was modified
setup_ssh_key
setup_github_cli
handle_git_clone
