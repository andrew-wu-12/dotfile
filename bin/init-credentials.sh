#!/bin/bash

credentials='{
    "credentials": [
        {
            "service_name": "jenkins.morrison.express",
            "variable_name": "JENKINS_TOKEN",
            "description": "Jenkins CI/CD 存取權杖，你可以從以下網站產生： \\e]8;;https://jenkins.morrison.express/\\e\\\\https://jenkins.morrison.express/\\e]8;;\\e\\\\"
        },
        {
            "service_name": "morrisonexpress.atlassian.net",
            "variable_name": "JIRA_TOKEN",
            "description": "Atlassian API Token（格式：email:token），你可以從以下網站取得： \\e]8;;https://id.atlassian.com/manage-profile/security/api-tokens\\e\\\\https://id.atlassian.com/manage-profile/security/api-tokens\\e]8;;\\e\\\\"
        },
        {
            "service_name": "getdata.morrison.express",
            "variable_name": "GETDATATOKEN",
            "description": "GetData API Token，你可以從以下網站取得： \\e]8;;https://morrisonexpress.atlassian.net/wiki/spaces/MOP/pages/2976415908/Project+Introduction\\e\\\\https://morrisonexpress.atlassian.net/wiki/spaces/MOP/pages/2976415908/Project+Introduction\\e]8;;\\e\\\\"
        }
    ]
}'

function handle_credentials() {
    echo ""
    echo "=== 憑證設定腳本 ==="
    echo ""
    
    # Parse credentials from JSON config
    cred_count=$(echo "$credentials" | jq -r '.credentials | length')
    
    # Process each credential
    for ((i=0; i<$cred_count; i++)); do
        service_name=$(echo "$credentials" | jq -r ".credentials[$i].service_name")
        variable_name=$(echo "$credentials" | jq -r ".credentials[$i].variable_name")
        description=$(echo "$credentials" | jq -r ".credentials[$i].description")
        
        echo ""
        printf "正在設定：%b \n" "$description"
        
        # Check if credential already exists in keychain
        existing=$(security find-generic-password -a "$USER" -s "$service_name" -w 2>/dev/null)
        
        if [ -n "$existing" ]; then
            read -p "已存在 $service_name 的憑證，是否更新？（y/n）：" update_choice </dev/tty
            if [[ ! "$update_choice" =~ ^[Yy]$ ]]; then
                echo "跳過 $service_name"
                continue
            fi
        fi
        
        # Prompt for credential (display description without escape sequences for the prompt)
        description_plain=$(echo "$credentials" | jq -r ".credentials[$i].description" | sed 's/\\e\]8;;[^\\]*\\e\\\\//g; s/\\e\]8;;\\e\\\\//g')
        read -r -s -p "請輸入你的 $description_plain：" credential_value </dev/tty
        echo "" 
        
        if [ -z "$credential_value" ]; then
            echo "⚠️  警告：輸入值為空，跳過 $service_name"
            continue
        fi
        
        # Store credential in macOS Keychain
        echo "正在將憑證儲存到 macOS Keychain..."
        security add-generic-password -a "$USER" -s "$service_name" -w "$credential_value" -U
        
        if [ $? -eq 0 ]; then
            echo "✓ 憑證已成功儲存到 Keychain"
        else
            echo "✗ 憑證儲存到 Keychain 失敗"
        fi
    done
    
    echo ""
    echo "✓ 憑證設定完成"
    echo "⚠️  注意：憑證會儲存在 macOS Keychain，並由 .zshrc 載入"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    handle_credentials
fi
