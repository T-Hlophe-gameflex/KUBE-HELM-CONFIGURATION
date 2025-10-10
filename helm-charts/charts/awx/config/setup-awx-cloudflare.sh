#!/bin/bash
# AWX Configuration Script for Cloudflare DNS Management
# This script sets up Job Templates, Surveys, and Projects in AWX

set -e

# Configuration variables
AWX_HOST="${AWX_HOST:-http://localhost:30080}"
AWX_USERNAME="${AWX_USERNAME:-admin}"
AWX_PASSWORD="${AWX_PASSWORD:-}"
PROJECT_REPO="${PROJECT_REPO:-https://github.com/your-org/cloudflare-playbooks.git}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if AWX CLI is available
check_awx_cli() {
    if ! command -v awx &> /dev/null; then
        error "AWX CLI not found. Please install it first:"
        echo "pip install awxkit"
        exit 1
    fi
}

# Login to AWX
login_awx() {
    log "Logging into AWX at $AWX_HOST"
    
    if [ -z "$AWX_PASSWORD" ]; then
        error "AWX_PASSWORD environment variable is required"
        echo "Export your AWX admin password: export AWX_PASSWORD='your-password'"
        exit 1
    fi
    
    awx login "$AWX_HOST" --username "$AWX_USERNAME" --password "$AWX_PASSWORD"
    success "Successfully logged into AWX"
}

# Create Organization (if needed)
create_organization() {
    log "Creating organization..."
    
    awx organizations create \
        --name "Cloudflare Operations" \
        --description "Organization for Cloudflare DNS management" \
        2>/dev/null || warning "Organization may already exist"
}

# Create Credential Type
create_credential_type() {
    log "Creating Cloudflare API credential type..."
    
    cat << 'EOF' > /tmp/cloudflare_credential_type.json
{
  "name": "Cloudflare API",
  "description": "Cloudflare API credentials",
  "kind": "cloud",
  "inputs": {
    "fields": [
      {
        "id": "api_token",
        "type": "string",
        "label": "Cloudflare API Token",
        "secret": true,
        "help_text": "Cloudflare API Token with DNS:Edit permissions"
      },
      {
        "id": "email", 
        "type": "string",
        "label": "Cloudflare Account Email",
        "help_text": "Your Cloudflare account email (for legacy auth)"
      },
      {
        "id": "global_api_key",
        "type": "string", 
        "label": "Cloudflare Global API Key",
        "secret": true,
        "help_text": "Cloudflare Global API Key (for legacy auth)"
      }
    ]
  },
  "injectors": {
    "env": {
      "CLOUDFLARE_API_TOKEN": "{{ api_token }}",
      "CLOUDFLARE_EMAIL": "{{ email }}",
      "CLOUDFLARE_API_KEY": "{{ global_api_key }}"
    }
  }
}
EOF

    awx credential_types create \
        --name "Cloudflare API" \
        --inputs @/tmp/cloudflare_credential_type.json \
        --injectors @/tmp/cloudflare_credential_type.json \
        2>/dev/null || warning "Credential type may already exist"
        
    rm /tmp/cloudflare_credential_type.json
}

# Create Project
create_project() {
    log "Creating Cloudflare DNS project..."
    
    awx projects create \
        --name "Cloudflare DNS Project" \
        --description "Cloudflare DNS management playbooks" \
        --scm_type "git" \
        --scm_url "$PROJECT_REPO" \
        --organization "Cloudflare Operations" \
        2>/dev/null || warning "Project may already exist"
}

# Create Inventory
create_inventory() {
    log "Creating localhost inventory..."
    
    # Create inventory
    awx inventories create \
        --name "localhost" \
        --description "Local execution inventory" \
        --organization "Cloudflare Operations" \
        2>/dev/null || warning "Inventory may already exist"
    
    # Add localhost host
    awx hosts create \
        --name "localhost" \
        --inventory "localhost" \
        --variables '{"ansible_connection": "local", "ansible_python_interpreter": "{{ ansible_playbook_python }}"}' \
        2>/dev/null || warning "Host may already exist"
}

# Create Job Template with Survey
create_job_template() {
    log "Creating Cloudflare DNS Management job template..."
    
    # Create job template
    awx job_templates create \
        --name "Cloudflare DNS Management" \
        --description "Dynamic Cloudflare DNS record management with survey support" \
        --job_type "run" \
        --inventory "localhost" \
        --project "Cloudflare DNS Project" \
        --playbook "cloudflare-dns-playbook.yml" \
        --verbosity 2 \
        --ask_variables_on_launch true \
        --survey_enabled true \
        2>/dev/null || warning "Job template may already exist"
    
    # Create survey
    log "Creating survey for job template..."
    
    cat << 'EOF' > /tmp/survey_spec.json
{
  "name": "Cloudflare DNS Management Survey",
  "description": "Configure DNS operations for Cloudflare domains",
  "spec": [
    {
      "question_name": "Domain Selection",
      "question_description": "Select the domain to manage",
      "required": true,
      "type": "multiplechoice",
      "variable": "survey_domain",
      "choices": [
        "example.com",
        "test-domain.com", 
        "dev.example.com",
        "staging.example.com",
        "prod.example.com"
      ],
      "default": "example.com"
    },
    {
      "question_name": "DNS Operation",
      "question_description": "Select the operation to perform",
      "required": true,
      "type": "multiplechoice",
      "variable": "survey_operation",
      "choices": [
        "create",
        "update", 
        "delete",
        "bulk_create",
        "list"
      ],
      "default": "create"
    },
    {
      "question_name": "Record Name",
      "question_description": "DNS record name (without domain)",
      "required": true,
      "type": "text",
      "variable": "survey_record_name",
      "default": "www",
      "min": 1,
      "max": 63
    },
    {
      "question_name": "Record Type",
      "question_description": "DNS record type",
      "required": true,
      "type": "multiplechoice",
      "variable": "survey_record_type",
      "choices": [
        "A",
        "AAAA",
        "CNAME",
        "MX",
        "TXT",
        "SRV",
        "CAA"
      ],
      "default": "A"
    },
    {
      "question_name": "Record Value",
      "question_description": "DNS record value (IP, hostname, or text)",
      "required": true,
      "type": "text",
      "variable": "survey_record_value",
      "default": "192.168.1.100",
      "min": 1,
      "max": 255
    },
    {
      "question_name": "TTL (Time To Live)",
      "question_description": "DNS record TTL in seconds",
      "required": false,
      "type": "multiplechoice",
      "variable": "survey_record_ttl",
      "choices": [
        "300",
        "1800",
        "3600",
        "7200",
        "14400",
        "28800",
        "86400"
      ],
      "default": "300"
    },
    {
      "question_name": "Cloudflare Proxy",
      "question_description": "Enable Cloudflare proxy (orange cloud)",
      "required": false,
      "type": "multiplechoice",
      "variable": "survey_record_proxied",
      "choices": [
        "false",
        "true"
      ],
      "default": "false"
    }
  ]
}
EOF

    awx job_templates modify "Cloudflare DNS Management" \
        --survey_spec @/tmp/survey_spec.json \
        2>/dev/null || warning "Survey may already exist"
        
    rm /tmp/survey_spec.json
}

# Create Zone Info Job Template
create_zone_info_template() {
    log "Creating Cloudflare Zone Info job template..."
    
    awx job_templates create \
        --name "Cloudflare Zone Info" \
        --description "Get Cloudflare zone information and DNS records" \
        --job_type "run" \
        --inventory "localhost" \
        --project "Cloudflare DNS Project" \
        --playbook "cloudflare-zone-info.yml" \
        --verbosity 1 \
        --survey_enabled true \
        2>/dev/null || warning "Job template may already exist"
    
    # Simple survey for domain selection
    cat << 'EOF' > /tmp/zone_survey.json
{
  "name": "Zone Information Survey",
  "description": "Select domain to inspect",
  "spec": [
    {
      "question_name": "Domain",
      "question_description": "Domain to inspect",
      "required": true,
      "type": "multiplechoice",
      "variable": "survey_domain",
      "choices": [
        "example.com",
        "test-domain.com",
        "dev.example.com",
        "staging.example.com",
        "prod.example.com"
      ],
      "default": "example.com"
    }
  ]
}
EOF

    awx job_templates modify "Cloudflare Zone Info" \
        --survey_spec @/tmp/zone_survey.json \
        2>/dev/null || warning "Survey may already exist"
        
    rm /tmp/zone_survey.json
}

# Main execution
main() {
    log "Starting AWX configuration for Cloudflare DNS Management"
    
    check_awx_cli
    login_awx
    create_organization
    create_credential_type
    create_project
    create_inventory
    create_job_template
    create_zone_info_template
    
    success "AWX configuration completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Create a Cloudflare API credential in AWX with your API token"
    echo "2. Associate the credential with your job templates"
    echo "3. Update the domain choices in the surveys to match your domains"
    echo "4. Run the job templates to manage your DNS records"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi