#!/bin/bash
# AWX Configuration Script for Cloudflare DNS Management
# Creates or updates the Cloudflare governance job templates and surveys

set -euo pipefail

AWX_HOST="${AWX_HOST:-http://localhost:30080}"
AWX_USERNAME="${AWX_USERNAME:-admin}"
AWX_PASSWORD="${AWX_PASSWORD:-}"
AWX_TOKEN="${AWX_TOKEN:-}"
AWX_VERIFY_SSL="${AWX_VERIFY_SSL:-false}"
ORGANIZATION="${ORGANIZATION:-Default}"
PROJECT_NAME="${PROJECT_NAME:-Cloudflare DNS Project}"
PROJECT_REPO="${PROJECT_REPO:-https://github.com/your-org/cloudflare-playbooks.git}"
INVENTORY_NAME="${INVENTORY_NAME:-localhost}"
HOST_NAME="${HOST_NAME:-localhost}"
CREDENTIAL_NAME="${CREDENTIAL_NAME:-Cloudflare API Credentials}"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARN:${NC} $1"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

fatal() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
    exit 1
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        fatal "Required command '$1' not found in PATH."
    fi
}

setup_awx_env() {
    export TOWER_HOST="${AWX_HOST}"
    export TOWER_VERIFY_SSL="${AWX_VERIFY_SSL}"
}

login_awx() {
    if [[ -n "${AWX_TOKEN}" ]]; then
        export TOWER_OAUTH_TOKEN="${AWX_TOKEN}"
        success "Using AWX token from environment."
        return
    fi

    if [[ -z "${AWX_PASSWORD}" ]]; then
        fatal "AWX_PASSWORD or AWX_TOKEN must be provided."
    fi

    log "Generating AWX API token for ${AWX_USERNAME}@${AWX_HOST}..."
    awx login -u "${AWX_USERNAME}" -p "${AWX_PASSWORD}" >/dev/null
    if [[ ! -f "${HOME}/.awx_token" ]]; then
        fatal "Failed to retrieve AWX token."
    fi

    AWX_TOKEN="$(<"${HOME}/.awx_token")"
    export AWX_TOKEN
    export TOWER_OAUTH_TOKEN="${AWX_TOKEN}"
    success "AWX token stored in ~/.awx_token."
}

awx_json() {
    awx "$@" -f json
}

get_id() {
    local resource="$1"
    local name="$2"
    shift 2
    awx "$resource" list --name "$name" "$@" -f json | python3 - "${name}" <<'PY'
import json
import sys
name = sys.argv[1]
try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    raise SystemExit(1)
if data.get("count"):
    print(data["results"][0]["id"])
else:
    print("")
PY
}

ensure_organization() {
    local org_id
    org_id=$(get_id organizations "${ORGANIZATION}")
    if [[ -z "${org_id}" ]]; then
        log "Creating organization '${ORGANIZATION}'..."
        awx organizations create --name "${ORGANIZATION}" >/dev/null
        org_id=$(get_id organizations "${ORGANIZATION}")
        success "Organization '${ORGANIZATION}' ready (id=${org_id})."
    else
        success "Organization '${ORGANIZATION}' present (id=${org_id})."
    fi
    echo "${org_id}"
}

ensure_project() {
    local org_id="$1"
    local project_id
    project_id=$(get_id projects "${PROJECT_NAME}")
    if [[ -z "${project_id}" ]]; then
        log "Creating project '${PROJECT_NAME}'..."
        awx projects create \
            --name "${PROJECT_NAME}" \
            --organization "${org_id}" \
            --scm_type git \
            --scm_url "${PROJECT_REPO}" >/dev/null
        project_id=$(get_id projects "${PROJECT_NAME}")
        success "Project '${PROJECT_NAME}' created (id=${project_id})."
    else
        log "Updating project '${PROJECT_NAME}' repo URL..."
        awx projects modify "${project_id}" --scm_url "${PROJECT_REPO}" >/dev/null
        success "Project '${PROJECT_NAME}' updated (id=${project_id})."
    fi
    echo "${project_id}"
}

ensure_inventory() {
    local org_id="$1"
    local inventory_id
    inventory_id=$(get_id inventories "${INVENTORY_NAME}")
    if [[ -z "${inventory_id}" ]]; then
        log "Creating inventory '${INVENTORY_NAME}'..."
        awx inventories create --name "${INVENTORY_NAME}" --organization "${org_id}" >/dev/null
        inventory_id=$(get_id inventories "${INVENTORY_NAME}")
        success "Inventory '${INVENTORY_NAME}' created (id=${inventory_id})."
    else
        success "Inventory '${INVENTORY_NAME}' present (id=${inventory_id})."
    fi

    local host_id
    host_id=$(awx hosts list --name "${HOST_NAME}" --inventory "${inventory_id}" -f json | python3 - <<'PY'
import json,sys
try:
    data=json.load(sys.stdin)
    print(data["results"][0]["id"] if data.get("count") else "")
except json.JSONDecodeError:
    print("")
PY
)
    if [[ -z "${host_id}" ]]; then
        log "Adding host '${HOST_NAME}' to inventory '${INVENTORY_NAME}'..."
        awx hosts create --name "${HOST_NAME}" --inventory "${inventory_id}" \
            --variables '{"ansible_connection": "local", "ansible_python_interpreter": "{{ ansible_playbook_python }}"}' >/dev/null
        success "Host '${HOST_NAME}' added."
    fi

    echo "${inventory_id}"
}

lookup_credential_id() {
    awx credentials list --name "${CREDENTIAL_NAME}" -f json | python3 - <<'PY'
import json,sys
try:
    data=json.load(sys.stdin)
    print(data["results"][0]["id"] if data.get("count") else "")
except json.JSONDecodeError:
    print("")
PY
}

write_survey() {
    local path="$1"
    local content="$2"
    printf '%s\n' "$content" >"${path}"
}

survey_domain_spec() {
cat <<'EOF'
{
  "name": "Domain Operations Survey",
  "description": "Select a domain, review the standard defaults, and capture DNS record details.",
  "spec": [
    {
      "question_name": "Domain",
      "question_description": "Domain to manage. Updated dynamically by the survey sync utility.",
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
      "question_name": "Record Name",
      "question_description": "Record host label (use '@' for the apex).",
      "required": true,
      "type": "text",
      "variable": "record_name",
      "default": "www",
      "min": 1,
      "max": 63
    },
    {
      "question_name": "Record Type",
      "question_description": "DNS record type to create or update.",
      "required": true,
      "type": "multiplechoice",
      "variable": "record_type",
      "choices": [
        "A",
        "AAAA",
        "CNAME",
        "MX",
        "TXT",
        "SRV",
        "CAA",
        "NS"
      ],
      "default": "A"
    },
    {
      "question_name": "Record Value",
      "question_description": "Target IP, hostname, or text content for the record.",
      "required": true,
      "type": "text",
      "variable": "record_value",
      "default": ""
    },
    {
      "question_name": "Record Comment",
      "question_description": "Optional comment to store with the record (max 100 characters).",
      "required": false,
      "type": "text",
      "variable": "record_comment",
      "default": "",
      "max": 100
    },
    {
      "question_name": "Record Tags",
      "question_description": "Optional comma-separated tags to attach to the record.",
      "required": false,
      "type": "text",
      "variable": "record_tags",
      "default": ""
    },
    {
      "question_name": "TTL",
      "question_description": "Time-to-live in seconds. 'auto' maps to Cloudflare's automatic TTL (300s).",
      "required": true,
      "type": "multiplechoice",
      "variable": "record_ttl",
      "choices": [
        "auto",
        "60",
        "120",
        "300",
        "600",
        "3600",
        "7200",
        "18000",
        "43200",
        "86400"
      ],
      "default": "auto"
    },
    {
      "question_name": "Proxy Status",
      "question_description": "Whether Cloudflare should proxy this record.",
      "required": true,
      "type": "multiplechoice",
      "variable": "record_proxied",
      "choices": [
        "true",
        "false"
      ],
      "default": "true"
    },
    {
      "question_name": "Apply Standard Zone Settings",
      "question_description": "Also enforce standardized zone settings for the selected domain after record changes.",
      "required": true,
      "type": "multiplechoice",
      "variable": "enforce_domain_standards",
      "choices": [
        "true",
        "false"
      ],
      "default": "true"
    },
    {
      "question_name": "Standards Profile",
      "question_description": "Path inside the project for the standards definition file.",
      "required": false,
      "type": "text",
      "variable": "standards_file",
      "default": "automation/cloudflare-standards.yml"
    }
  ]
}
EOF
}

survey_global_spec() {
cat <<'EOF'
{
  "name": "Global Baseline Survey",
  "description": "Select domains and confirm global record standards to enforce.",
  "spec": [
    {
      "question_name": "Target Domains",
      "question_description": "Domains to normalize. Leave empty to include all managed domains from the standards profile.",
      "required": false,
      "type": "multiselect",
      "variable": "target_domains",
      "choices": [
        "example.com",
        "test-domain.com",
        "dev.example.com",
        "staging.example.com",
        "prod.example.com"
      ],
      "default": ""
    },
    {
      "question_name": "Enforce TTL",
      "question_description": "Override defaults for the run. 'auto' converts to Cloudflare's automatic TTL.",
      "required": false,
      "type": "multiplechoice",
      "variable": "global_record_ttl",
      "choices": [
        "",
        "auto",
        "60",
        "120",
        "300",
        "600",
        "3600",
        "7200",
        "18000",
        "43200",
        "86400"
      ],
      "default": ""
    },
    {
      "question_name": "Enforce Proxy Status",
      "question_description": "Leave blank to keep standards file defaults.",
      "required": false,
      "type": "multiplechoice",
      "variable": "global_record_proxied",
      "choices": [
        "",
        "true",
        "false"
      ],
      "default": ""
    },
    {
      "question_name": "Standards Profile",
      "question_description": "Path inside the project for the standards definition file.",
      "required": false,
      "type": "text",
      "variable": "standards_file",
      "default": "automation/cloudflare-standards.yml"
    }
  ]
}
EOF
}

survey_platform_spec() {
cat <<'EOF'
{
  "name": "Platform Sync Survey",
  "description": "Choose template and target domains, then select the preset or record keys to synchronize.",
  "spec": [
    {
      "question_name": "Template Domain",
      "question_description": "Source domain for the record clone operation.",
      "required": true,
      "type": "multiplechoice",
      "variable": "template_domain",
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
      "question_name": "Target Domains",
      "question_description": "Domains that should receive the records.",
      "required": true,
      "type": "multiselect",
      "variable": "target_domains",
      "choices": [
        "example.com",
        "test-domain.com",
        "dev.example.com",
        "staging.example.com",
        "prod.example.com"
      ],
      "default": ""
    },
    {
      "question_name": "Platform Preset",
      "question_description": "Preset from the standards file describing which record keys to sync.",
      "required": true,
      "type": "multiplechoice",
      "variable": "platform_preset",
      "choices": [
        "full",
        "web-only"
      ],
      "default": "full"
    },
    {
      "question_name": "Record Keys Override",
      "question_description": "Optional comma-separated list of record keys to sync instead of the preset.",
      "required": false,
      "type": "text",
      "variable": "record_keys",
      "default": ""
    },
    {
      "question_name": "Standards Profile",
      "question_description": "Path inside the project for the standards definition file.",
      "required": false,
      "type": "text",
      "variable": "standards_file",
      "default": "automation/cloudflare-standards.yml"
    }
  ]
}
EOF
}

survey_zone_info_spec() {
cat <<'EOF'
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
}

ensure_job_template() {
    local name="$1"
    local description="$2"
    local playbook="$3"
    local extra_vars="$4"
    local survey_json="$5"
    local project_id="$6"
    local inventory_id="$7"
    local credential_id="$8"

    local template_id
    template_id=$(get_id job_templates "${name}")

    if [[ -z "${template_id}" ]]; then
        log "Creating job template '${name}'..."
        local create_cmd=(awx job_templates create
            --name "${name}"
            --description "${description}"
            --job_type run
            --inventory "${inventory_id}"
            --project "${project_id}"
            --playbook "${playbook}"
            --verbosity 1
            --ask_variables_on_launch true
            --survey_enabled true
            --extra_vars "${extra_vars}")
        if [[ -n "${credential_id}" ]]; then
            create_cmd+=(--credential "${credential_id}")
        fi
        if ! "${create_cmd[@]}" >/dev/null 2>&1; then
            warn "Template '${name}' already exists; proceeding to update."
        else
            success "Template '${name}' created."
        fi
        template_id=$(get_id job_templates "${name}")
    fi

    log "Updating job template '${name}' settings..."
    local modify_cmd=(awx job_templates modify "${template_id}"
        --description "${description}"
        --job_type run
        --inventory "${inventory_id}"
        --project "${project_id}"
        --playbook "${playbook}"
        --verbosity 1
        --ask_variables_on_launch true
        --survey_enabled true
        --extra_vars "${extra_vars}")
    if [[ -n "${credential_id}" ]]; then
        modify_cmd+=(--credential "${credential_id}")
    fi
    "${modify_cmd[@]}" >/dev/null

    local survey_file="${TMPDIR}/survey-$(echo "${name}" | tr ' ' '-')".json
    write_survey "${survey_file}" "${survey_json}"
    awx job_templates survey_spec "${template_id}" --set @"${survey_file}" >/dev/null
    success "Survey for '${name}' applied."
}

main() {
    log "Starting AWX configuration for Cloudflare governance workflows"

    require_cmd awx
    require_cmd python3

    setup_awx_env
    login_awx

    local org_id project_id inventory_id credential_id
    org_id=$(ensure_organization)
    project_id=$(ensure_project "${org_id}")
    inventory_id=$(ensure_inventory "${org_id}")
    credential_id=$(lookup_credential_id)
    if [[ -z "${credential_id}" ]]; then
        warn "Credential '${CREDENTIAL_NAME}' not found. Templates will be created without a default credential."
    else
        success "Using credential '${CREDENTIAL_NAME}' (id=${credential_id})."
    fi

    ensure_job_template \
        "Cloudflare Domain Operations" \
        "Manage domain-level DNS records with standards-aware defaults" \
        "automation/cloudflare-standardize.yml" \
        '{"workflow":"manage_record","enforce_domain_standards":true}' \
        "$(survey_domain_spec)" \
        "${project_id}" \
        "${inventory_id}" \
        "${credential_id}"

    ensure_job_template \
        "Cloudflare Global Baseline" \
        "Normalize TTL and proxy posture across managed domains" \
        "automation/cloudflare-standardize.yml" \
        '{"workflow":"global_standardize"}' \
        "$(survey_global_spec)" \
        "${project_id}" \
        "${inventory_id}" \
        "${credential_id}"

    ensure_job_template \
        "Cloudflare Platform Sync" \
        "Clone standard record presets from a template domain into peers" \
        "automation/cloudflare-standardize.yml" \
        '{"workflow":"platform_sync"}' \
        "$(survey_platform_spec)" \
        "${project_id}" \
        "${inventory_id}" \
        "${credential_id}"

    ensure_job_template \
        "Cloudflare Zone Info" \
        "Get Cloudflare zone information and DNS records" \
        "cloudflare-zone-info.yml" \
        '{}' \
        "$(survey_zone_info_spec)" \
        "${project_id}" \
        "${inventory_id}" \
        "${credential_id}"

    success "AWX configuration completed successfully."
    echo
    echo "Next steps:"
    echo "  1. Verify the Cloudflare API credential '${CREDENTIAL_NAME}' exists or create it and re-run if necessary."
    echo "  2. Run automation/cloudflare-sync-survey.yml to refresh live domain choices."
    echo "  3. Launch the job template that matches your workflow (Domain Operations, Global Baseline, Platform Sync)."
}

main "$@"