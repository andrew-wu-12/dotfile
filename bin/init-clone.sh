#!/bin/bash

#function handle_git_clone: clone project to path defined in .zshrc
function handle_git_clone() {
    echo ""
    echo "=== Git Repository Clone Script ==="
    echo ""
    
    # Construct git_project JSON with current environment variables
    # This is done here so variables have actual values
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

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    handle_git_clone
fi
