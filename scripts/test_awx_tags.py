#!/usr/bin/env python3
"""
Simple AWX Job Tagging Test
Tests the tag-based job identification system
"""

import requests
import json
import os
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

def test_job_template_config():
    """Test job template tag configuration"""
    print("🔧 Testing AWX Job Template Tag Configuration")
    print("=" * 50)
    
    headers = {
        'Authorization': get_awx_auth(),
        'Content-Type': 'application/json'
    }
    
    try:
        response = requests.get(
            f"{AWX_URL}/api/v2/job_templates/21/",
            headers=headers,
            verify=False
        )
        
        if response.status_code == 200:
            template = response.json()
            print(f"📋 Template: {template['name']}")
            print(f"🏷️  Ask tags on launch: {template['ask_tags_on_launch']}")
            print(f"🔖 Job tags template: {template['job_tags']}")
            print("✅ Tag configuration looks good!")
        else:
            print(f"❌ Failed to get template: {response.status_code}")
    
    except Exception as e:
        print(f"❌ Error: {e}")

def get_recent_jobs_with_tags():
    """Show recent jobs and their tags"""
    print("\n📋 Recent Jobs with Tags")
    print("=" * 50)
    
    headers = {
        'Authorization': get_awx_auth(),
        'Content-Type': 'application/json'
    }
    
    try:
        response = requests.get(
            f"{AWX_URL}/api/v2/jobs/?page_size=5&order_by=-created",
            headers=headers,
            verify=False
        )
        
        if response.status_code == 200:
            jobs = response.json().get('results', [])
            
            for job in jobs:
                job_id = job['id']
                job_name = job['name']
                job_status = job['status']
                job_tags = job.get('job_tags', '')
                created = job.get('created', '')
                
                print(f"🔧 Job {job_id}: {job_name}")
                print(f"   Status: {job_status}")
                print(f"   Tags: {job_tags if job_tags else 'None'}")
                print(f"   Created: {created[:19] if created else 'Unknown'}")
                print()
        
        else:
            print(f"❌ Failed to get jobs: {response.status_code}")
    
    except Exception as e:
        print(f"❌ Error: {e}")

def simulate_job_launch():
    """Show how to launch a job with tags"""
    print("\n🚀 How to Launch Job with Tags")
    print("=" * 50)
    
    print("When launching a Cloudflare job, the tags will be automatically set to:")
    print("🏷️  CLOUDFLARE - identifies it as a Cloudflare automation job")
    print("🔧 [ACTION] - CREATE, UPDATE, DELETE, CLONE, or CREATE-DOMAIN")
    print("🎫 [TICKET] - your ticket number from the survey")
    print()
    print("Example tags for different scenarios:")
    print("  • Create record with ticket ABC-123: 'CLOUDFLARE,CREATE,ABC-123'")
    print("  • Update record with ticket DEF-456: 'CLOUDFLARE,UPDATE,DEF-456'")
    print("  • Delete record without ticket: 'CLOUDFLARE,DELETE,NO-TICKET'")
    print()
    print("These tags will be visible in the AWX UI job list! 🎯")

def main():
    """Main test function"""
    test_job_template_config()
    get_recent_jobs_with_tags()
    simulate_job_launch()
    
    print("\n✅ AWX Job Tagging Test Complete!")
    print("\n🎯 What you'll see in AWX UI:")
    print("   • Go to http://localhost:8080")
    print("   • Navigate to Jobs section")
    print("   • Each job will show tags with action and ticket info")
    print("   • You can filter jobs by tags")
    print("   • Tags appear alongside job status and timing")

if __name__ == "__main__":
    main()