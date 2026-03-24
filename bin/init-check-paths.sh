#!/bin/bash

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
    declare -a path_issues=()
    declare -a updated_paths=()
    
    # Extract paths from config file
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
                    # Update in the config file
                    # Use a temp file for cross-platform compatibility
                    temp_file=$(mktemp)
                    sed "s|export $var_name=\".*\"|export $var_name=\"$new_path\"|" "$DOTFILE_ZSHRC" > "$temp_file"
                    mv "$temp_file" "$DOTFILE_ZSHRC"
                    
                    echo "✓ Updated $var_name to $new_path in config"
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

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_and_fix_paths
fi
