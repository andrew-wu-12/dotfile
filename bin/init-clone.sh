#!/bin/bash

#function handle_git_clone: clone project to path defined in .zshrc
function handle_git_clone() {
    echo ""
    echo "=== Git 儲存庫複製腳本 ==="
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
    echo "正在確認 GitHub 驗證狀態..."
    gh auth status 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "✗ GitHub CLI 尚未完成驗證"
        echo "⚠️  請先確認 'setup_github_cli' 已成功執行後再進行此步驟"
        return 1
    fi
    
    echo "✓ GitHub 驗證已確認"
    echo ""
    
    # Parse the number of projects from JSON
    project_count=$(echo "$git_project" | jq -r '.projects | length')
    
    # Process each project
    for ((i=0; i<$project_count; i++)); do
        repo_name=$(echo "$git_project" | jq -r ".projects[$i].name")
        repo_path=$(echo "$git_project" | jq -r ".projects[$i].path")
        
        # Expand $HOME in the path
        expanded_path="${repo_path/\$HOME/$HOME}"
        
        echo "正在檢查儲存庫：$repo_name"
        echo "目標路徑：$expanded_path"
        
        # Check if repository already exists
        if [ -d "$expanded_path/.git" ]; then
            echo "✓ 儲存庫 '$repo_name' 已存在於 $expanded_path"
            echo ""
            continue
        fi
        
        # Check if directory exists but is not a git repo
        if [ -d "$expanded_path" ] && [ ! -d "$expanded_path/.git" ]; then
            echo "⚠️  目錄已存在，但不是 git 儲存庫：$expanded_path"
            read -p "要刪除它並重新複製嗎？（y/n）：" remove_choice </dev/tty
            
            if [[ "$remove_choice" =~ ^[Yy]$ ]]; then
                rm -rf "$expanded_path"
                echo "✓ 已刪除現有目錄"
            else
                echo "跳過 $repo_name"
                echo ""
                continue
            fi
        fi
        
        # Create parent directory if it doesn't exist
        parent_dir=$(dirname "$expanded_path")
        if [ ! -d "$parent_dir" ]; then
            echo "正在建立父目錄：$parent_dir"
            mkdir -p "$parent_dir"
        fi
        
        # Clone the repository
        echo "正在複製儲存庫 '$repo_name'..."
        gh repo clone "$repo_name" "$expanded_path"
        
        if [ $? -eq 0 ]; then
            echo "✓ 已成功複製 $repo_name"
        else
            echo "✗ 複製 $repo_name 失敗"
        fi
        echo ""
    done
    
    echo "✓ Git 儲存庫複製完成"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    handle_git_clone
fi
