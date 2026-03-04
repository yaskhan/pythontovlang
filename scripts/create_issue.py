#!/usr/bin/env python3
"""
Script to create GitHub issues from a text file template using GitHub CLI.

Format of the input file:
##title: Your Issue Title Here
##descr: Your issue description here.
         Can span multiple lines.
---cut---
##title: Another Issue Title
##descr: Another description.
---cut---

Usage:
    python create_issue.py issues.txt [--repo owner/repo] [--label label1,label2]
"""

import subprocess
import sys
import argparse
from pathlib import Path


def parse_issues_file(filepath: str) -> list[dict]:
    """Parse the issues file and return a list of issue dictionaries."""
    issues = []
    current_issue = {}
    current_section = None
    current_content = []
    
    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.rstrip('\n')
            
            if line.startswith('##title:'):
                # Save previous issue if exists
                if current_issue and 'title' in current_issue:
                    current_issue['description'] = '\n'.join(current_content).strip()
                    issues.append(current_issue)
                    current_content = []
                
                current_issue = {'title': line[8:].strip()}
                current_section = 'title'
                
            elif line.startswith('##descr:'):
                current_section = 'descr'
                # Start collecting description content
                desc_start = line[8:].strip()
                if desc_start:
                    current_content.append(desc_start)
                    
            elif line.strip() == '---cut---':
                # End of current issue
                if current_issue and 'title' in current_issue:
                    current_issue['description'] = '\n'.join(current_content).strip()
                    issues.append(current_issue)
                current_issue = {}
                current_content = []
                current_section = None
                
            elif current_section == 'descr':
                # Continue collecting description
                current_content.append(line)
    
    # Don't forget the last issue if file doesn't end with ---cut---
    if current_issue and 'title' in current_issue and current_content:
        current_issue['description'] = '\n'.join(current_content).strip()
        issues.append(current_issue)
    
    return issues


def create_issue(title: str, description: str, repo: str | None = None, labels: list[str] | None = None) -> bool:
    """Create a GitHub issue using gh CLI."""
    cmd = ['gh', 'issue', 'create', '--title', title, '--body', description]
    
    if repo:
        cmd.extend(['--repo', repo])
    
    if labels:
        for label in labels:
            cmd.extend(['--label', label])
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True, encoding='utf-8')
        print(f"[OK] Created issue: {title}")
        if result.stdout:
            print(f"  {result.stdout.strip()}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Failed to create issue: {title}")
        if e.stderr:
            print(f"  Error: {e.stderr.strip()}")
        return False


def main():
    parser = argparse.ArgumentParser(description='Create GitHub issues from a text file')
    parser.add_argument('input_file', help='Path to the issues text file')
    parser.add_argument('--repo', '-r', help='GitHub repository (owner/repo)')
    parser.add_argument('--label', '-l', help='Comma-separated labels to apply to all issues')
    parser.add_argument('--dry-run', '-n', action='store_true', help='Show what would be created without actually creating')
    
    args = parser.parse_args()
    
    # Check if input file exists
    if not Path(args.input_file).exists():
        print(f"Error: File '{args.input_file}' not found")
        sys.exit(1)
    
    # Parse issues
    issues = parse_issues_file(args.input_file)
    
    if not issues:
        print("No issues found in the file")
        sys.exit(1)
    
    print(f"Found {len(issues)} issue(s) to create\n")
    
    # Parse labels
    labels = None
    if args.label:
        labels = [l.strip() for l in args.label.split(',')]
    
    # Create issues
    created = 0
    failed = 0
    
    for issue in issues:
        if args.dry_run:
            print(f"[DRY RUN] Would create: {issue['title']}")
            print(f"  Description: {issue['description'][:100]}...")
            if labels:
                print(f"  Labels: {', '.join(labels)}")
            print()
            created += 1
        else:
            if create_issue(issue['title'], issue['description'], args.repo, labels):
                created += 1
            else:
                failed += 1
    
    print(f"\nSummary: {created} created, {failed} failed")


if __name__ == '__main__':
    main()
