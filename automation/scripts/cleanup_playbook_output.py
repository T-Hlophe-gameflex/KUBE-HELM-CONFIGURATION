#!/usr/bin/env python3
"""
Playbook Output Cleanup Script
Removes unnecessary debug statements and adds categorized output
"""

import re
import sys

# Debug statements to remove (by task name pattern)
REMOVE_DEBUG_TASKS = [
    r'List all DNS records for this domain \(debug\)',
    r'Output all DNS records for this domain \(debug\)',
    r'No DNS records fetched \(debug fallback\)',
    r'Optionally show full DNS records JSON when debug_curl is true',
    r'Display current DNS records for this domain',
    r'Debug page rules counts',
    r'Show AWX PATCH payload \(dry-run\)',
    r'Debug page rules apply results',
]

# Tasks to simplify (convert verbose output to categorized)
SIMPLIFY_TASKS = {
    'Output zone settings result': '🌐 DOMAIN LEVEL │ Zone Settings Applied',
    'Display page rules API warning if applicable': '⚠ DOMAIN LEVEL │ Page Rules Warning',  
    'Warn AWX survey update failed': '⚠ PLATFORM LEVEL │ AWX Survey Update Failed',
    'Critical info summary \(concise\)': '📋 DOMAIN LEVEL │ Record Operation Summary',
}

def clean_playbook(content):
    """Remove unnecessary debugs and improve output"""
    lines = content.split('\n')
    result = []
    skip_until_next_task = False
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Check if this is a task to remove
        if '- name:' in line:
            task_name = line.split('- name:')[1].strip()
            
            # Remove debug tasks
            should_remove = any(re.search(pattern, task_name) for pattern in REMOVE_DEBUG_TASKS)
            
            if should_remove:
                # Skip this task and its debug block
                skip_until_next_task = True
                i += 1
                continue
        
        # Skip debug block content
        if skip_until_next_task:
            # Check if we've reached the next task or block end
            if (line.strip().startswith('- name:') or 
                (line.strip().startswith('-') and 'name:' not in line and len(line.strip()) > 2)):
                skip_until_next_task = False
            else:
                i += 1
                continue
        
        result.append(line)
        i += 1
    
    return '\n'.join(result)

if __name__ == '__main__':
    input_file = sys.argv[1] if len(sys.argv) > 1 else 'unified-cloudflare-awx-playbook.yml'
    
    with open(input_file, 'r') as f:
        content = f.read()
    
    cleaned = clean_playbook(content)
    
    with open(input_file, 'w') as f:
        f.write(cleaned)
    
    print(f"✓ Cleaned {input_file}")
    print(f"  Removed unnecessary debug statements")
