#!/bin/bash

#check if following package is installed: jq, gh, curl, git, stow, if not run install script
packages=("jq" "gh" "curl" "git" "stow" "nvm" "zoxide")

credentials='{
    "credentials": [
        {
            "service_name": "jenkins.morrison.express",
            "variable_name": "JENKINS_TOKEN",
            "description": "Jenkins CI/CD Access Token, you can generate one from site provided below: \\e]8;;https://id.atlassian.com/manage-profile/security/api-tokens\\e\\\\https://id.atlassian.com/manage-profile/security/api-tokens\\e]8;;\\e\\\\"
        },
        {
            "service_name": "morrisonexpress.atlassian.net",
            "variable_name": "JIRA_TOKEN",
            "description": "Atlassian API Token (email:token), you can get your token from site provided below: \\e]8;;https://jenkins.morrison.express/\\e\\\\https://jenkins.morrison.express/\\e]8;;\\e\\\\"
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
    
    ZSHRC_FILE="$HOME/.zshrc"
    DOTFILE_ZSHRC="../.zshrc"
    
    # Check if dotfile zshrc exists
    if [ ! -f "$DOTFILE_ZSHRC" ]; then
        echo "⚠️  Warning: Dotfile zshrc not found at $DOTFILE_ZSHRC"
        return
    fi
    
    # Array to track issues found
    declare -a path_issues=()
    
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
        echo "✓ All configured paths exist"
        return
    fi
    
    echo ""
    echo "Found ${#path_issues[@]} path issue(s):"
    for issue in "${path_issues[@]}"; do
        echo "  ⚠️  $issue"
    done
    
    echo ""
    read -p "Would you like to review all your path settings again? (y/n): " fix_choice
    
    if [[ ! "$fix_choice" =~ ^[Yy]$ ]]; then
        echo "Skipping path corrections"
        return
    fi
    check_and_fix_paths
    echo ""
    echo "✓ Path Check Complete"
}

function handle_credentials() {
    echo ""
    echo "=== Credentials Setup Script ==="
    echo ""
    
    ZSHRC_FILE="$HOME/.zshrc"
    
    # Parse credentials from JSON config
    cred_count=$(echo "$credentials" | jq -r '.credentials | length')
    
    # Remove old insecure exports if they exist
    echo "Cleaning up old insecure credential exports..."
    sed -i '' '/export JENKINS_TOKEN=/d' "$ZSHRC_FILE" 2>/dev/null
    sed -i '' '/export JIRA_TOKEN=/d' "$ZSHRC_FILE" 2>/dev/null
    sed -i '' '/export GETDATATOKEN=/d' "$ZSHRC_FILE" 2>/dev/null
    
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
    
    # Add secure credential retrieval functions to .zshrc
    echo ""
    echo "Setting up secure credential retrieval functions..."
    
    # Remove old functions if they exist
    sed -i '' '/# Secure credential retrieval functions/,/^}$/d' "$ZSHRC_FILE" 2>/dev/null
    
    # Start building the functions section
    echo "" >> "$ZSHRC_FILE"
    echo "# Secure credential retrieval functions (tokens never exposed in environment)" >> "$ZSHRC_FILE"
    echo "# Added by init.sh - Do not edit manually" >> "$ZSHRC_FILE"
    
    # Generate a function for each credential dynamically
    for ((i=0; i<$cred_count; i++)); do
        service_name=$(echo "$credentials" | jq -r ".credentials[$i].service_name")
        variable_name=$(echo "$credentials" | jq -r ".credentials[$i].variable_name")
        
        # Append function to .zshrc
        cat >> "$ZSHRC_FILE" << EOF
        export $variable_name=\$(security find-generic-password -a "\$USER" -s "$service_name" -w 2>/dev/null)
EOF
    done
    echo "✓ Added secure credential retrieval functions to .zshrc"
    echo "✓ Credentials Setup Complete"
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
    
    # Authenticate with GitHub first
    echo "Authenticating with GitHub..."
    # gh auth login
    
    # Check if authentication was successful
    # zsh
    if [ $? -ne 0 ]; then
        echo "✗ GitHub authentication failed. Please check your credentials."
        exit 1
    fi
    
    echo "✓ GitHub authentication successful"
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
    cd ..
    stow zsh
    #check if $HOME/bin exists, if not create it
    if [ ! -d "$HOME/bin" ]; then
        mkdir "$HOME/bin"
        echo "Created $HOME/bin directory"
    fi
    stow --target=$HOME/bin bin
    cd $HOME/bin
    echo "✓ Stowing complete"
}

install_package
install_oh_my_zsh
stow_config
check_and_fix_paths
handle_credentials

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

handle_git_clone
