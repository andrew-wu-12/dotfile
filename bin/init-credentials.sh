#!/bin/bash

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
            read -p "Credential already exists for $service_name. Update? (y/n): " update_choice </dev/tty
            if [[ ! "$update_choice" =~ ^[Yy]$ ]]; then
                echo "Skipping $service_name"
                continue
            fi
        fi
        
        # Prompt for credential (display description without escape sequences for the prompt)
        description_plain=$(echo "$credentials" | jq -r ".credentials[$i].description" | sed 's/\\e\]8;;[^\\]*\\e\\\\//g; s/\\e\]8;;\\e\\\\//g')
        read -p "Enter your $description_plain: " credential_value </dev/tty
        
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

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    handle_credentials
fi
