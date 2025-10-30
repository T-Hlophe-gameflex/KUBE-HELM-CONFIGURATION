# AWX Cloudflare Automation Documentation

## Overview

This document provides comprehensive information about the AWX Cloudflare automation setup, including survey configuration, available actions, settings management, and maintenance procedures.

## AWX Setup Architecture

### Core Components

**AWX Installation**
- Deployed via Ansible AWX Operator in Kubernetes namespace `awx`
- Main components: Web UI, Task Manager, PostgreSQL database, Redis cache
- Access via port-forward: `kubectl port-forward -n awx svc/ansible-awx-service 8052:80`

**Project Structure**
- Main playbook: `automation/playbooks/cloudflare/cloudflare_awx_playbook.yml`
- Task modules: `automation/playbooks/cloudflare/tasks/`
- Configuration templates: `automation/playbooks/cloudflare/*.j2`
- Management scripts: `scripts/`

## Survey Configuration

### Current Survey Setup

**Template Name**: Cloudflare - Automation
**Template ID**: 21
**Description**: Cloudflare configuration management. Streamlined DNS operations, zone settings, and domain administration automation.

### Survey Fields

| Field Name | Variable | Type | Default Value | Description |
|------------|----------|------|---------------|-------------|
| Action | `cf_action` | multiplechoice | `create_record` | Operation to perform (create/update/delete/clone/create_domain/update_settings) |
| Domain | `existing_domain` | multiplechoice |`[DOMAINS]` | Domain selection from Cloudflare account |
| Manual Domain Entry | `manual_domain` | text | *(empty)* | Manual domain entry when not in dropdown |
| Record Name | `record_name` | text | *(empty)* | DNS record name/subdomain |
| Existing Record | `existing_record` | multiplechoice | `[NONE]` | Existing record selection (populated dynamically) |
| Record Type | `record_type` | multiplechoice | `A` | DNS record type (A, AAAA, CNAME, MX, TXT, SRV) |
| Record Value | `record_value` | text | *(empty)* | Record content (IP, hostname, text) |
| TTL | `record_ttl` | multiplechoice | `auto` | Time to live setting |
| Priority | `record_priority` | integer | `10` | Priority for MX/SRV records (0-65535) |
| Proxy Through Cloudflare | `global_proxied` | multiplechoice | `true` | Enable Cloudflare proxy (orange cloud) |
| Edge Cache TTL | `edge_ttl_value` | integer | `14400` | Edge cache TTL in seconds (0-31536000) |
| Cache Level | `cache_level` | multiplechoice | `aggressive` | Cloudflare cache level |
| Security Level | `security_level` | multiplechoice | `full` | SSL/TLS security setting |

### Survey Management

The AWX survey configuration is managed through a consolidated script that handles all survey-related operations:

**Unified Survey Management Script**: `scripts/awx_survey_manager.sh`

```bash
# Apply improved survey configuration
./scripts/awx_survey_manager.sh apply-survey

# Verify current survey state
./scripts/awx_survey_manager.sh verify-changes

# Update template name and description
./scripts/awx_survey_manager.sh update-template

# Show current survey configuration
./scripts/awx_survey_manager.sh show-current
```

**Key Features**:
- Consolidates all survey management functionality
- Professional field names and descriptions
- Comprehensive error handling and status reporting
- Template branding and description updates

## Available Actions

### DNS Record Operations

#### create_record
**Purpose**: Create new DNS records in specified domain
**Process**: 
1. Validates domain and record parameters
2. Applies automatic Cloudflare rules (force_https, cache_level, etc.)
3. Creates DNS record with specified configuration
4. Applies job labels for tracking

**Files Involved**:
- Main logic: `tasks/manage_dns_record.yml`
- Variable preparation: `tasks/prepare_record_variables.yml`
- Rule application: `tasks/apply_single_modern_rule.yml`

#### update_record
**Purpose**: Modify existing DNS record properties
**Process**:
1. Locates existing record by name and type
2. Updates content, TTL, proxy status as specified
3. Maintains existing values for unspecified fields
4. Applies modern rules if requested

**Files Involved**:
- Record management: `tasks/manage_dns_record.yml`
- Settings update: `tasks/update_record_settings.yml`

#### delete_record
**Purpose**: Remove DNS records from domain
**Process**:
1. Identifies target record by name and type
2. Performs deletion via Cloudflare API
3. Tracks operation in domain_changes log

**Files Involved**:
- Deletion logic: `tasks/manage_dns_record.yml`

#### clone_record
**Purpose**: Copy DNS record from source domain to target domain
**Process**:
1. Retrieves source record configuration
2. Adapts record for target domain
3. Creates equivalent record with same settings
4. Maintains record relationships and dependencies

**Files Involved**:
- Cloning logic: `tasks/manage_dns_record.yml`
- Cross-domain operations: `tasks/prepare_record_variables.yml`

### Domain Management

#### create_domain
**Purpose**: Set up new domain with standard configuration
**Process**:
1. Validates domain ownership and access
2. Applies default zone settings
3. Creates essential DNS records
4. Configures security and performance rules

**Files Involved**:
- Zone setup: `tasks/apply_zone_settings.yml`
- Standards application: `helm-charts/charts/awx/config/cloudflare-standards.yml`

#### update_settings
**Purpose**: Modify Cloudflare configurations at different levels
**Process**: Depends on settings_level parameter

**Zone Level** (`settings_level: zone`):
- SSL/TLS configuration
- Security settings
- Performance optimizations
- Protocol support

**Record Level** (`settings_level: record`):
- TTL modifications
- Proxy status changes
- Content updates

**Account Level** (`settings_level: account`):
- Account-wide security policies
- Global access control settings

**Files Involved**:
- Zone settings: `tasks/update_zone_settings.yml`
- Record settings: `tasks/update_record_settings.yml`

## Settings Management

### Zone-Level Settings

**File**: `tasks/update_zone_settings.yml`

**Categories**:
- **SSL/TLS**: ssl, min_tls_version, always_use_https, automatic_https_rewrites
- **Security**: security_level, challenge_ttl, browser_check, waf
- **Performance**: cache_level, browser_cache_ttl, brotli, rocket_loader
- **Optimization**: polish, webp, image_resizing, mirage
- **Protocols**: http2, http3, websockets, ipv6, tls_1_3, zero_rtt
- **Protection**: hotlink_protection, email_obfuscation, server_side_exclude

### Record-Level Settings

**File**: `tasks/update_record_settings.yml`

**Configurable Properties**:
- TTL (Time to Live)
- Proxy status (Cloudflare proxy on/off)
- Record content (IP addresses, hostnames, text values)

### Default Configurations

**File**: `tasks/prepare_record_variables.yml`

**Default Values**:
- TTL: 3600 seconds (1 hour)
- Proxy status: true (enabled by default)
- Cache level: aggressive
- Security level: full SSL

## Rule Application System

### Automatic Rules

**File**: `tasks/apply_single_modern_rule.yml`

**Applied Rules**:
- force_https: Redirect HTTP to HTTPS
- redirect_to_www: Canonical www subdomain
- cache_level: Aggressive caching
- edge_cache_ttl: Edge cache duration
- argo_smart_routing: Intelligent routing
- cache_everything: Comprehensive caching
- browser_cache_ttl: Browser cache control

**Trigger Conditions**:
- create_record, update_record, clone_record, create_domain actions
- Valid zone_id present
- Domain resolution successful

## Job Labels and Tracking

### Label System

**File**: `tasks/manage_job_labels.yml`

**Label Types**:
- Action labels: CREATE, UPDATE, DELETE, CLONE, UPDATE-SETTINGS
- Record type labels: A, AAAA, CNAME, MX, TXT, SRV
- Domain labels: DOMAIN-NAME (dots replaced with hyphens)

**Application Process**:
1. Creates labels in AWX organization
2. Applies labels to current job instance
3. Enables filtering and identification in AWX UI

## Execution Summary

### Output Format

**File**: Main playbook execution summary section

**Information Displayed**:
- Action performed and target domain
- Settings level (if applicable)
- Domain-level changes count and details
- Global-level changes count and details
- Platform-level changes count and details

## File Structure Reference

### Core Playbook Files
```
automation/playbooks/cloudflare/
├── cloudflare_awx_playbook.yml          # Main orchestration
├── survey_spec.json.j2                  # Survey template
├── cloudflare_modern_rules.j2           # Rules template
└── tasks/
    ├── manage_job_labels.yml             # Job labeling
    ├── prepare_record_variables.yml      # Variable setup
    ├── manage_dns_record.yml             # DNS operations
    ├── apply_zone_settings.yml           # Zone configuration
    ├── update_zone_settings.yml          # Zone updates
    ├── update_record_settings.yml        # Record updates
    └── apply_single_modern_rule.yml      # Rule application
```

### Management Scripts
```
scripts/
├── apply_survey_improvements.sh         # Update survey config
├── verify_awx_changes.sh                # Verify changes
├── update_awx_template_description.sh   # Update template info
└── apply_survey_updates.sh              # Apply survey changes
```

### Configuration Files
```
helm-charts/charts/awx/config/
├── cloudflare-standards.yml             # Standard configurations
├── setup-awx-cloudflare.sh              # AWX setup script
└── sync-cloudflare-domains.yml          # Domain sync automation
```

## Maintenance Procedures

### Survey Updates
1. Modify survey configuration in appropriate script
2. Run `./scripts/apply_survey_improvements.sh`
3. Verify changes with `./scripts/verify_awx_changes.sh`

### Template Information Updates
1. Edit `scripts/update_awx_template_description.sh`
2. Update NEW_DESCRIPTION and NEW_NAME variables
3. Execute script to apply changes

### Configuration Standards Updates
1. Modify `helm-charts/charts/awx/config/cloudflare-standards.yml`
2. Update standard_records, standard_zone_settings, or platform_presets
3. Test sync action to verify changes

### Task Logic Modifications
1. Edit relevant task files in `automation/playbooks/cloudflare/tasks/`
2. Test changes in development environment
3. Deploy to production AWX instance

## Authentication and Access

### AWX Access
- Username: admin
- Password: Retrieved from Kubernetes secret `ansible-awx-admin-password`
- Access command: `kubectl get secret ansible-awx-admin-password -n awx -o jsonpath="{.data.password}" | base64 -d`

### Cloudflare API
- Authentication via CLOUDFLARE_API_TOKEN environment variable
- Token requires zone and DNS permissions
- Configured in AWX credential store

### Port Forwarding
```bash
kubectl port-forward -n awx svc/ansible-awx-service 8052:80
```

This documentation provides complete reference for maintaining and extending the AWX Cloudflare automation system.