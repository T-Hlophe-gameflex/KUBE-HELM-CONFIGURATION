#!/usr/bin/env python3
"""
Test AWX Job Labeling System
Tests the automatic action-based labeling functionality
"""

import requests
import json
import os
import sys
from base64 import b64encode

# AWX Configuration
AWX_URL = "http://localhost:8080"
AWX_USERNAME = "admin"
AWX_PASSWORD = os.environ.get('AWX_PASSWORD', 'admin')

def get_awx_auth():
    """Get AWX Basic Auth header"""
    credentials = f"{AWX_USERNAME}:{AWX_PASSWORD}"
    encoded_credentials = b64encode(credentials.encode()).decode()
    return f"Basic {encoded_credentials}"

def get_action_label_id(action):
    """Get label ID for given action"""
    try:
        headers = {
            'Authorization': get_awx_auth(),
            'Content-Type': 'application/json'
        }
        
        response = requests.get(
            f"{AWX_URL}/api/v2/labels/?name={action}",
            headers=headers,
            verify=False
        )
        
        if response.status_code == 200:
            results = response.json().get('results', [])
            if results:
                return results[0]['id']
        return None
    except Exception as e:
        print(f"❌ Error getting label ID for {action}: {e}")
        return None

def test_action_labels():
    """Test all action labels exist"""
    actions = ['CREATE', 'UPDATE', 'DELETE', 'CLONE', 'CREATE-DOMAIN']
    
    print("🔍 Testing Action Labels in AWX...")
    print("=" * 50)
    
    for action in actions:
        label_id = get_action_label_id(action)
        if label_id:
            print(f"✅ {action:<15} → Label ID: {label_id}")
        else:
            print(f"❌ {action:<15} → Not found")
    
    return True

def get_recent_jobs():
    """Get recent jobs from AWX"""
    try:
        headers = {
            'Authorization': get_awx_auth(),
            'Content-Type': 'application/json'
        }
        
        response = requests.get(
            f"{AWX_URL}/api/v2/jobs/?page_size=5&order_by=-created",
            headers=headers,
            verify=False
        )
        
        if response.status_code == 200:
            return response.json().get('results', [])
        return []
    except Exception as e:
        print(f"❌ Error getting jobs: {e}")
        return []

def check_job_labels():
    """Check if recent jobs have labels"""
    jobs = get_recent_jobs()
    
    print("\n🏷️  Checking Recent Job Labels...")
    print("=" * 50)
    
    if not jobs:
        print("❌ No recent jobs found")
        return
    
    for job in jobs[:3]:  # Check last 3 jobs
        job_id = job['id']
        job_name = job['name']
        job_status = job['status']
        
        # Get job labels
        try:
            headers = {
                'Authorization': get_awx_auth(),
                'Content-Type': 'application/json'
            }
            
            response = requests.get(
                f"{AWX_URL}/api/v2/jobs/{job_id}/labels/",
                headers=headers,
                verify=False
            )
            
            if response.status_code == 200:
                labels = response.json().get('results', [])
                label_names = [label['name'] for label in labels]
                
                print(f"🔧 Job {job_id}: {job_name}")
                print(f"   Status: {job_status}")
                if label_names:
                    print(f"   Labels: {', '.join(label_names)}")
                else:
                    print(f"   Labels: None")
                print()
            
        except Exception as e:
            print(f"❌ Error checking job {job_id}: {e}")

def main():
    """Main test function"""
    print("🚀 AWX Job Labeling System Test")
    print("=" * 50)
    
    # Test 1: Check if action labels exist
    test_action_labels()
    
    # Test 2: Check recent job labels
    check_job_labels()
    
    print("✅ Label testing completed!")
    print("\nTo see labels in AWX UI:")
    print("1. Go to http://localhost:8080")
    print("2. Navigate to Jobs section")
    print("3. Look for labels column showing action types")

if __name__ == "__main__":
    main()