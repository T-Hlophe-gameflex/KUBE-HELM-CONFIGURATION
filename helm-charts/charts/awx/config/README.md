# AWX Cloudflare DNS Management Configuration
 
This directory contains configuration files and scripts for setting up Cloudflare DNS management in AWX with dynamic surveys and job templates.

## Files Overview

### Playbooks
- `cloudflare-dns-playbook.yml` - Main playbook for DNS operations with survey support
- `cloudflare-zone-info.yml` - Playbook for retrieving zone information

### Configuration
- `job-templates.yml` - AWX job template and survey definitions
- `setup-awx-cloudflare.sh` - Automated setup script for AWX

## Setup Instructions

### 1. Deploy AWX
First, deploy AWX using the Helm chart:

```bash
# Set AWX deployment flag and deploy
ansible-playbook ../../../playbooks/main.yml -e deploy_awx=true
```

### 2. Get AWX Admin Password
```bash
# Wait for AWX to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=awx -n awx --timeout=600s

# Get admin password
kubectl get secret ansible-awx-admin-password -o jsonpath="{.data.password}" -n awx | base64 --decode
```

### 3. Access AWX Web Interface
```bash
# Get AWX service details
kubectl get svc -n awx

# Access via NodePort (default: 30080)
# URL: http://<node-ip>:30080
# Username: admin
# Password: <from step 2>
```

### 4. Configure AWX for Cloudflare

#### Option A: Manual Configuration
1. Log into AWX web interface
2. Create a new Organization: "Cloudflare Operations"
3. Create a new Project linked to your Git repository containing the playbooks
4. Create an inventory with localhost
5. Import the job templates and surveys from `job-templates.yml`

#### Option B: Automated Configuration
```bash
# Install AWX CLI
pip install awxkit

# Set environment variables
export AWX_HOST="http://<your-awx-host>:30080"
export AWX_USERNAME="admin"
export AWX_PASSWORD="<your-admin-password>"

# Run the setup script
./setup-awx-cloudflare.sh
```

### 5. Create Cloudflare API Credentials
1. In AWX, go to Resources → Credentials
2. Create a new credential with type "Cloudflare API"
3. Enter your Cloudflare API token or email/global API key
4. Associate this credential with your job templates

### 6. Customize Domain Choices
Edit the survey specifications to include your actual domains:
1. Go to Templates → Cloudflare DNS Management
2. Click on the survey tab
3. Modify the domain choices to match your Cloudflare zones

## Survey Features

### Domain Selection
- Dropdown list of available domains
- Easily customizable through survey configuration

### DNS Operations
- **Create**: Add new DNS records
- **Update**: Modify existing DNS records  
- **Delete**: Remove DNS records
- **Bulk Create**: Create multiple records from JSON
- **List**: Display all records for a zone

### Record Types Supported
- A (IPv4 address)
- AAAA (IPv6 address)
- CNAME (Canonical name)
- MX (Mail exchange)
- TXT (Text record)
- SRV (Service record)
- CAA (Certificate Authority Authorization)

### Dynamic Configuration
- TTL selection (5 minutes to 24 hours)
- Cloudflare proxy toggle (orange cloud)
- Bulk operations via JSON input
- Zone ID optimization

## Usage Examples

### Single Record Creation
1. Launch "Cloudflare DNS Management" job template
2. Select domain from dropdown
3. Choose "create" operation
4. Enter record details (name, type, value)
5. Configure TTL and proxy settings
6. Execute job

### Bulk Record Creation
1. Launch job template with "bulk_create" operation
2. Provide JSON array in the bulk records field:
```json
[
  {
    "name": "api",
    "type": "A",
    "value": "192.168.1.101",
    "ttl": 300,
    "proxied": true
  },
  {
    "name": "mail",
    "type": "A", 
    "value": "192.168.1.102",
    "ttl": 3600,
    "proxied": false
  }
]
```

### Zone Information
1. Launch "Cloudflare Zone Info" job template
2. Select domain to inspect
3. View comprehensive zone details and record summary

## Security Considerations

### API Token Permissions
Create a Cloudflare API token with minimal required permissions:
- Zone:Zone:Read (for zone information)
- Zone:DNS:Edit (for DNS record management)

### AWX Access Control
- Create separate AWX users for different teams
- Use AWX role-based access control
- Limit job template permissions based on user roles

## Troubleshooting

### Common Issues
1. **Authentication Errors**: Verify Cloudflare API credentials
2. **Zone Not Found**: Check domain spelling and zone access
3. **Permission Denied**: Ensure API token has required permissions
4. **Job Failures**: Check AWX job output for detailed error messages

### Debug Mode
Enable verbose logging by setting verbosity to 3 in job templates for detailed debugging information.

## Extending the Configuration

### Adding New Domains
1. Update survey specifications in job templates
2. Add domain choices to the dropdown lists
3. Ensure API credentials have access to new zones

### Custom Record Types
1. Modify playbooks to support additional record types
2. Update survey choices to include new types
3. Test with non-standard record configurations

### Integration with Other Systems
- Use AWX REST API for programmatic job launches
- Integrate with CI/CD pipelines for automated DNS updates
- Connect with monitoring systems for dynamic record management