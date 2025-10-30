# Cloudflare DNS Errors - Quick Reference

## Common DNS Record Errors

### Error 9039: CNAME content cannot reference itself

**What it means**: You're trying to create a CNAME record that points to itself, creating a circular reference.

**Example of invalid configuration**:
```yaml
domain: example.com
record_name: www
record_type: CNAME
record_value: www.example.com  # ❌ Points to itself!
```

**How to fix**:
1. Change the CNAME target to a different hostname
2. Or use an A/AAAA record instead if you want to point to an IP

**Valid alternatives**:
```yaml
# Option 1: Point to different hostname
record_value: origin.example.com  # ✅

# Option 2: Point to external service
record_value: yourdomain.cdn.com  # ✅

# Option 3: Use A record instead
record_type: A
record_value: 203.0.113.10  # ✅
```

**Validation**: The playbook now automatically detects this error before making the API call.

---

### Error 81053: An A, AAAA, or CNAME record with that host already exists

**What it means**: A DNS record with the same name already exists, and you're trying to create a duplicate.

**How the playbook handles it**:
- Automatically detects the duplicate
- Attempts to convert `create_record` to `update_record`
- Updates the existing record instead of creating duplicate

**Manual fix if needed**:
```bash
# Use update_record action explicitly
cf_action: update_record
existing_domain: example.com
record_name: www
record_type: A
record_value: 203.0.113.50
```

**Note**: The auto-convert logic is implemented but may have limitations in some edge cases.

---

### Error 81058: The record already exists

**What it means**: Similar to 81053, but for other record types.

**Handled by**: Same auto-convert logic as error 81053.

---

### Error 9005: Content for A record must be a valid IPv4 address

**What it means**: You're trying to create an A record with content that isn't a valid IPv4 address (e.g., hostname instead of IP).

**Example of invalid configuration**:
```yaml
record_type: A
record_value: example.com  # ❌ Hostname, not IP!
```

**How to fix**:

**Option 1**: Use a CNAME record instead (if pointing to hostname)
```yaml
record_type: CNAME
record_value: example.com  # ✅
```

**Option 2**: Use the correct IP address
```yaml
record_type: A
record_value: 203.0.113.10  # ✅
```

**Validation**: The playbook now automatically detects invalid IPv4 addresses before making the API call.

**Common mistakes**:
- Using hostname instead of IP: `example.com` → Should be `203.0.113.10`
- Using IPv6 for A record: `2001:db8::1` → Use AAAA record instead
- Typos in IP: `192.168.1` (missing octet) → Should be `192.168.1.1`
- Invalid octets: `999.999.999.999` → Each octet must be 0-255

---

### Error 9006: Content for AAAA record must be a valid IPv6 address

**What it means**: You're trying to create an AAAA record with content that isn't a valid IPv6 address.

**Example of invalid configuration**:
```yaml
record_type: AAAA
record_value: 192.168.1.1  # ❌ IPv4, not IPv6!
```

**How to fix**:

**Option 1**: Use an A record for IPv4
```yaml
record_type: A
record_value: 192.168.1.1  # ✅
```

**Option 2**: Use valid IPv6 address
```yaml
record_type: AAAA
record_value: 2001:0db8:85a3::8a2e:0370:7334  # ✅
```

**Validation**: The playbook validates IPv6 format before making the API call.

---

### Error 1004: DNS Validation Error

**What it means**: Invalid DNS record content for the specified record type.

**Common causes**:

#### 1. CNAME pointing to an IP address
```yaml
record_type: CNAME
record_value: 192.168.1.1  # ❌ Invalid!
```

**Fix**: Use A or AAAA record type
```yaml
record_type: A
record_value: 192.168.1.1  # ✅
```

#### 2. Invalid MX priority
```yaml
record_type: MX
record_priority: "high"  # ❌ Must be a number!
```

**Fix**: Use numeric priority
```yaml
record_priority: 10  # ✅
```

#### 3. Missing required fields
```yaml
record_type: MX
record_value: mail.example.com
# Missing record_priority!  # ❌
```

**Fix**: Add all required fields
```yaml
record_priority: 10  # ✅
```

---

### Error 1003: Invalid record name

**What it means**: The record name contains invalid characters or format.

**Invalid characters**: Spaces, special characters (except hyphens and underscores in specific positions)

**Examples**:
```yaml
record_name: "my record"      # ❌ Contains space
record_name: "record@name"    # ❌ Invalid character
record_name: "_dmarc"         # ✅ Valid (underscore prefix for specific records)
record_name: "my-record"      # ✅ Valid
```

---

### Error 9208: Failed to parse. ttl must be a number

**What it means**: The TTL value is not a valid integer.

**How the playbook handles it**: The `update_settings` action now properly converts TTL to integer using `| to_json`.

**Valid TTL values**:
- `1` - Automatic (for proxied records)
- `60` - 1 minute
- `300` - 5 minutes
- `600` - 10 minutes
- `1800` - 30 minutes
- `3600` - 1 hour (default)
- `86400` - 1 day

**Fix in AWX**: Ensure TTL is passed as a number, not a string:
```yaml
record_ttl: 3600  # ✅ Not "3600"
```

---

### Error 1006: Record type requires content

**What it means**: The record_value field is missing or empty.

**Fix**:
```yaml
record_type: A
record_value: 203.0.113.10  # ✅ Must provide IP address
```

---

### Error 1009: Invalid record type

**What it means**: The record_type is not supported or misspelled.

**Valid record types**:
- `A` - IPv4 address
- `AAAA` - IPv6 address
- `CNAME` - Canonical name (alias)
- `MX` - Mail exchange
- `TXT` - Text record
- `SRV` - Service record
- `NS` - Name server
- `CAA` - Certification Authority Authorization
- `PTR` - Pointer record

**Fix**: Use one of the valid types above.

---

## Troubleshooting Steps

### Step 1: Check the Error Code
Look at the `json.errors[].code` in the playbook output:
```json
"errors": [{"code": 9039, "message": "CNAME content cannot reference itself."}]
```

### Step 2: Verify Record Parameters
Check your input values:
- `record_name`: Correct subdomain?
- `record_type`: Valid type?
- `record_value`: Correct format for the type?
- `record_priority`: Provided for MX/SRV records?

### Step 3: Check Existing Records
Before creating, check if the record already exists:
```bash
curl -X GET "https://api.cloudflare.com/client/v4/zones/ZONE_ID/dns_records?name=FULL_RECORD_NAME" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Step 4: Use Update Instead of Create
If the record exists, use `update_record` action:
```yaml
cf_action: update_record
existing_domain: example.com
record_name: www
record_type: A
record_value: 203.0.113.50
```

### Step 5: Check Cloudflare Plan Limitations
Some features require paid plans:
- Multiple records with same name
- Lower TTL values
- Certain record types

---

## Prevention

### Use Validation Actions
The playbook now includes built-in validations:
- ✅ CNAME IP address check
- ✅ CNAME self-reference check
- ✅ Duplicate record detection
- ✅ Type conversion (TTL, proxied)

### Test in Development Mode
```yaml
cf_action: update_settings
settings_level: zone
existing_domain: example.com
development_mode: "on"  # Bypass cache for testing
```

### Use AWX Survey Dropdowns
Configure AWX surveys with:
- Predefined record types (dropdown)
- Valid TTL values (dropdown)
- Existing domain selection (dynamic dropdown)
- Existing record selection (dynamic dropdown)

---

## Quick Reference Table

| Error Code | Error Message | Solution |
|------------|---------------|----------|
| 9005 | Content for A record must be valid IPv4 | Use valid IP or change to CNAME for hostnames |
| 9006 | Content for AAAA record must be valid IPv6 | Use valid IPv6 or change to A for IPv4 |
| 9039 | CNAME content cannot reference itself | Use different target or A record |
| 81053 | A/AAAA/CNAME record already exists | Use update_record or let auto-convert handle it |
| 81058 | Record already exists | Use update_record action |
| 1003 | Invalid record name | Remove invalid characters, use hyphens only |
| 1004 | DNS Validation Error | Check record content matches type |
| 1006 | Record type requires content | Provide record_value |
| 1009 | Invalid record type | Use valid type (A, AAAA, CNAME, MX, TXT, etc.) |
| 9208 | ttl must be a number | Ensure TTL is integer, not string |

---

## Related Documentation
- [UPDATE-SETTINGS-GUIDE.md](./UPDATE-SETTINGS-GUIDE.md) - Settings management
- [UPDATE-SETTINGS-AWX-QUICK-START.md](./UPDATE-SETTINGS-AWX-QUICK-START.md) - AWX usage
- [ZONE-SETTINGS-TROUBLESHOOTING.md](./ZONE-SETTINGS-TROUBLESHOOTING.md) - Zone settings issues
- [Cloudflare API Docs](https://developers.cloudflare.com/api/operations/dns-records-for-a-zone-create-dns-record) - Official reference
