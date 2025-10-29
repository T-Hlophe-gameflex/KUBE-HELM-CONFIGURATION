# Cloudflare AWX Template - Complete Testing Checklist

## Testing Date: October 29, 2025
## AWX URL: http://127.0.0.1:8052
## Template: Cloudflare AWX Survey (ID: 21)

---

## 📋 Pre-Testing Setup

### Environment Check
- [ ] AWX is running and accessible
- [ ] Cloudflare API Token is set: `j6NsfyFG-EsBTDxnZCdsiEy8QAdyliiJgxdz4n7x`
- [ ] Project updated to latest code (commit: bdc9755)
- [ ] Survey has 10 questions
- [ ] Domains in Cloudflare: efustryton.co.za, efutechnologies.co.za

### Survey Field Verification
- [ ] **Question 1**: cf_action (multiplechoice) - create_domain, create_record, update_record, delete_record, clone_record
- [ ] **Question 2**: domain (multiplechoice) - dropdown with zones
- [ ] **Question 3**: record_name (text) - for NEW records
- [ ] **Question 4**: existing_record_name (multiplechoice) - dropdown with existing records
- [ ] **Question 5**: record_type (multiplechoice) - A, AAAA, CNAME, TXT, MX, SRV, NS, CAA
- [ ] **Question 6**: record_value (text) - record content
- [ ] **Question 7**: global_ttl (integer) - default 3600
- [ ] **Question 8**: record_priority (integer) - default 10 (for MX/SRV)
- [ ] **Question 9**: global_proxied (multiplechoice) - default TRUE
- [ ] **Question 10**: rule_action (multiplechoice) - none, force_https, redirect_to_www, etc.

---

## 🧪 Test Cases by Action

### 1. CREATE_DOMAIN (Create Zone)

#### Test 1.1: Create New Domain
**Input:**
```
cf_action: create_domain
domain: test-domain-123.com
rule_action: none
```

**Expected Result:**
- [ ] New zone created in Cloudflare
- [ ] Zone ID returned
- [ ] Job completes successfully
- [ ] Summary shows: Action=create_domain, Domain=test-domain-123.com

**Actual Result:**
```
Status: ___________
Zone ID: ___________
Notes: ___________
```

---

### 2. CREATE_RECORD (Create DNS Record)

#### Test 2.1: Create A Record (Proxied)
**Input:**
```
cf_action: create_record
domain: efutechnologies.co.za
record_name: test-api
existing_record_name: none
record_type: A
record_value: 192.168.1.100
global_ttl: 3600
record_priority: 10
global_proxied: true
rule_action: none
```

**Expected Result:**
- [ ] A record created: test-api.efutechnologies.co.za → 192.168.1.100
- [ ] Proxied (orange cloud) enabled
- [ ] TTL: 3600
- [ ] Record ID returned
- [ ] Job completes successfully

**Actual Result:**
```
Status: ___________
Record ID: ___________
Proxied: ___________
Notes: ___________
```

#### Test 2.2: Create CNAME Record (Not Proxied)
**Input:**
```
cf_action: create_record
domain: efutechnologies.co.za
record_name: test-cname
record_type: CNAME
record_value: efutechnologies.co.za
global_proxied: false
```

**Expected Result:**
- [ ] CNAME record created
- [ ] Points to efutechnologies.co.za
- [ ] Not proxied (gray cloud)

**Actual Result:**
```
Status: ___________
Notes: ___________
```

#### Test 2.3: Create TXT Record
**Input:**
```
cf_action: create_record
record_name: _test-txt
record_type: TXT
record_value: v=test123
```

**Expected Result:**
- [ ] TXT record created
- [ ] Value properly quoted in JSON
- [ ] No proxy option (not applicable)

**Actual Result:**
```
Status: ___________
Notes: ___________
```

#### Test 2.4: Create MX Record (with Priority)
**Input:**
```
cf_action: create_record
record_name: @
record_type: MX
record_value: mail.efutechnologies.co.za
record_priority: 10
```

**Expected Result:**
- [ ] MX record created
- [ ] Priority: 10
- [ ] Points to mail.efutechnologies.co.za
- [ ] No TypeError about missing priority

**Actual Result:**
```
Status: ___________
Priority field included: ___________
Notes: ___________
```

#### Test 2.5: Create Record with Modern Rule (force_https)
**Input:**
```
cf_action: create_record
record_name: secure-test
record_type: A
record_value: 192.168.1.101
rule_action: force_https
```

**Expected Result:**
- [ ] A record created
- [ ] Modern redirect rule created
- [ ] Rule description: "Force HTTPS redirect for efutechnologies.co.za"
- [ ] Ruleset phase: http_request_dynamic_redirect
- [ ] Rule ID returned

**Actual Result:**
```
Record Status: ___________
Rule Status: ___________
Rule ID: ___________
Notes: ___________
```

---

### 3. UPDATE_RECORD (Update DNS Record)

#### Test 3.1: Update Existing Record (using dropdown)
**Input:**
```
cf_action: update_record
domain: efutechnologies.co.za
record_name: (leave empty)
existing_record_name: test-api.efutechnologies.co.za
record_type: A
record_value: 192.168.1.200
global_proxied: false
```

**Expected Result:**
- [ ] Existing test-api record updated
- [ ] IP changed to 192.168.1.200
- [ ] Proxied disabled (orange → gray cloud)
- [ ] Uses existing_record_name from dropdown

**Actual Result:**
```
Status: ___________
New IP: ___________
Proxied changed: ___________
Notes: ___________
```

#### Test 3.2: Update TTL Only
**Input:**
```
cf_action: update_record
existing_record_name: test-api.efutechnologies.co.za
global_ttl: 7200
```

**Expected Result:**
- [ ] TTL updated to 7200 (2 hours)
- [ ] Other fields unchanged

**Actual Result:**
```
Status: ___________
New TTL: ___________
```

---

### 4. DELETE_RECORD (Delete DNS Record)

#### Test 4.1: Delete Record by Dropdown Selection
**Input:**
```
cf_action: delete_record
domain: efutechnologies.co.za
existing_record_name: test-api.efutechnologies.co.za
```

**Expected Result:**
- [ ] Record deleted successfully
- [ ] Confirmation message shown
- [ ] Record no longer visible in Cloudflare dashboard

**Actual Result:**
```
Status: ___________
Deleted Record ID: ___________
Notes: ___________
```

#### Test 4.2: Delete Non-Existent Record (Error Handling)
**Input:**
```
cf_action: delete_record
existing_record_name: nonexistent.efutechnologies.co.za
```

**Expected Result:**
- [ ] Graceful error message
- [ ] Job doesn't crash
- [ ] Clear error explanation

**Actual Result:**
```
Status: ___________
Error Message: ___________
```

---

### 5. CLONE_RECORD (Duplicate DNS Record)

#### Test 5.1: Clone Existing Record
**Input:**
```
cf_action: clone_record
domain: efutechnologies.co.za
existing_record_name: wellington.efutechnologies.co.za
record_name: wellington-clone
```

**Expected Result:**
- [ ] New record created with cloned settings
- [ ] Name: wellington-clone.efutechnologies.co.za
- [ ] Same type, value, TTL, proxy as original
- [ ] No TypeError (body_format: json fix applied)

**Actual Result:**
```
Status: ___________
Cloned Record ID: ___________
Settings Match: ___________
Notes: ___________
```

---

## 🔧 Modern Rules Testing

### Test 6.1: force_https Rule
**Input:**
```
cf_action: create_record
record_name: https-test
record_type: A
record_value: 192.168.1.50
rule_action: force_https
```

**Expected Result:**
- [ ] Record created
- [ ] Redirect rule created
- [ ] Expression: `(http.request.ssl == false)`
- [ ] Target: https://domain
- [ ] Status: 301

**Actual Result:**
```
Record: ___________
Rule Created: ___________
Rule Phase: ___________
```

### Test 6.2: redirect_to_www Rule
**Input:**
```
rule_action: redirect_to_www
domain: efustryton.co.za
```

**Expected Result:**
- [ ] Rule redirects apex → www
- [ ] Expression: `(http.host eq "efustryton.co.za")`
- [ ] Target: https://www.efustryton.co.za

**Actual Result:**
```
Rule Status: ___________
```

### Test 6.3: browser_cache_ttl Rule
**Input:**
```
rule_action: browser_cache_ttl
```

**Expected Result:**
- [ ] Cache rule created
- [ ] Browser TTL: 300 seconds (5 minutes)
- [ ] Phase: http_request_cache_settings
- [ ] Description: "Set browser cache TTL to 5 minutes"

**Actual Result:**
```
Rule Status: ___________
Cache TTL: ___________
```

---

## 🔍 Error Scenarios Testing

### Test 7.1: Missing Required Fields
**Input:**
```
cf_action: create_record
domain: efutechnologies.co.za
(no record_name, no record_type)
```

**Expected Result:**
- [ ] Validation error before API call
- [ ] Clear error message
- [ ] Job fails gracefully

**Actual Result:**
```
Error: ___________
```

### Test 7.2: Invalid Record Type
**Input:**
```
record_type: INVALID
record_value: test
```

**Expected Result:**
- [ ] Cloudflare API error
- [ ] Error displayed clearly
- [ ] No job crash

**Actual Result:**
```
Error: ___________
```

### Test 7.3: Invalid Domain
**Input:**
```
domain: not-in-cloudflare.com
```

**Expected Result:**
- [ ] Zone not found error
- [ ] Clear message
- [ ] No crash

**Actual Result:**
```
Error: ___________
```

---

## 📊 Performance & Integration Tests

### Test 8.1: Job Execution Time
- [ ] create_record: _____ seconds
- [ ] update_record: _____ seconds
- [ ] delete_record: _____ seconds
- [ ] create_domain: _____ seconds

**Target:** < 30 seconds per job

### Test 8.2: API Token Validation
- [ ] Valid token works
- [ ] Invalid token shows clear error
- [ ] Token permissions sufficient

### Test 8.3: Concurrent Jobs
- [ ] Run 2 jobs simultaneously
- [ ] Both complete successfully
- [ ] No race conditions

---

## ✅ Final Verification Checklist

### Code Quality
- [x] No legacy page rules code executing
- [x] All TypeError fixes applied (body_format: json)
- [x] Template paths correct (../../templates/)
- [x] AWX token hardcoded (not empty)
- [x] Priority field included for MX/SRV
- [x] Browser cache TTL = 5 minutes

### Survey Configuration
- [ ] 10 questions total
- [ ] All dropdowns populated
- [ ] Defaults correct (proxied=true, ttl=3600, priority=10)
- [ ] Modern rules options available

### Playbook Functionality
- [ ] All 5 actions work (create_domain, create_record, update_record, delete_record, clone_record)
- [ ] Modern rules apply correctly
- [ ] Error handling works
- [ ] No auto-refresh dropdowns (removed)

### Documentation
- [x] MODERNIZATION-SUMMARY.md exists
- [x] README files updated
- [ ] Testing checklist completed

---

## 🐛 Known Issues (If Any)

### Issue 1:
```
Description: ___________
Workaround: ___________
Status: ___________
```

### Issue 2:
```
Description: ___________
Workaround: ___________
Status: ___________
```

---

## 📝 Testing Notes

**Date:** ___________  
**Tester:** ___________  
**Environment:** ___________  
**Overall Status:** ⬜ Pass | ⬜ Fail | ⬜ Partial  

**Additional Comments:**
```
___________
___________
___________
```

---

## 🎯 Success Criteria

For this template to be considered production-ready:

- [ ] All 5 main actions (create_domain, create_record, update_record, delete_record, clone_record) work
- [ ] At least 3 different record types tested (A, CNAME, TXT)
- [ ] MX/SRV records create with priority field
- [ ] At least 2 modern rules tested (force_https, browser_cache_ttl)
- [ ] Error handling works for invalid inputs
- [ ] No TypeErrors or file not found errors
- [ ] Job execution time < 30 seconds
- [ ] All tests documented in this checklist

**Overall Grade:** ⬜ READY | ⬜ NEEDS WORK | ⬜ BLOCKED

---

## 🚀 Next Steps After Testing

1. [ ] Document any bugs found
2. [ ] Create issues for failed tests
3. [ ] Update README with testing results
4. [ ] Tag release version if all pass
5. [ ] Deploy to production environment
