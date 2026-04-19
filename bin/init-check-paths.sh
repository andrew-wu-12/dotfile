#!/bin/bash

# Ensure Bash version 4.0+ is being used
if ((BASH_VERSINFO[0] < 4)); then
    echo "Error: Bash version 4+ required. Current version: $BASH_VERSION"
    exit 1
fi

function check_and_fix_paths() {
    echo ""
    echo "=== Path Configuration Check ==="
    echo ""
    
    # Detect environment: Dotfiles repo vs Standalone MCP
    if [ -f "../zsh/.zshrc" ]; then
        DOTFILE_ZSHRC="../zsh/.zshrc"
        echo "Running in dotfiles repo mode. Targeting: $DOTFILE_ZSHRC"
    else
        DOTFILE_ZSHRC="$HOME/.zshrc"
        echo "Running in standalone mode. Targeting: $DOTFILE_ZSHRC"
    fi
    
    # Ensure .zshrc exists
    if [ ! -f "$DOTFILE_ZSHRC" ]; then
        echo "Creating $DOTFILE_ZSHRC..."
        touch "$DOTFILE_ZSHRC"
    fi
    
    # Define default paths
    declare -A defaults
    defaults["MOP_CONFIGURATION_PATH"]="$HOME/project/mop_configuration_files"
    defaults["MOP_CONSOLE_PATH"]="$HOME/project/mop_console"
    defaults["MOP_MONOREPO_PATH"]="$HOME/project/mop-console-monorepo"
    defaults["MOP_EPOD_PATH"]="$HOME/project/mop_epod"

    # Inject missing variables
    for var in "${!defaults[@]}"; do
        if ! grep -q "export $var=" "$DOTFILE_ZSHRC"; then
            echo "Injecting default $var..."
            echo "export $var=\"${defaults[$var]}\"" >> "$DOTFILE_ZSHRC"
        fi
    done

    # Array to track issues found
    path_issues=()
    updated_paths=()

    # Check project paths
    echo "Checking path configurations..."
    while IFS= read -r line; do
        if [[ $line =~ export[[:space:]]+(MOP[A-Z_]*PATH)="([^"]+)" ]]; then
            var_name="${BASH_REMATCH[1]}"
            var_value="${BASH_REMATCH[2]}"
            
            # Expand $HOME in the path
            expanded_path="${var_value/\$HOME/$HOME}"

            # Display current variable and ask user for modifications if non-interactive sessions are supported
            echo ""
            echo "Found: $var_name=$var_value"
            read -p "Does this path need to be modified? (Press n if repos are not cloned yet) (y/n): " modify_choice
            
            if [[ "$modify_choice" =~ ^[Yy]$ ]]; then
                read -p "Enter new path (use \$HOME for home directory): " new_path
                if [ -n "$new_path" ]; then
                    # Update in the config file
                    temp_file=$(mktemp)
                    sed "s|export $var_name=\".*\"|export $var_name=\"$new_path\"|" "$DOTFILE_ZSHRC" > "$temp_file"
                    mv "$temp_file" "$DOTFILE_ZSHRC"
                    
                    echo "✓ Updated $var_name to $new_path in config"
                
                    # Update var_value for subsequent operations.
                fi
            fi
            #directories configuration saved over init