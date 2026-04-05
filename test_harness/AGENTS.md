# Kimiz Test Harness

## Description
This is a test harness for the Kimiz Harness Engineering Platform.

## Behavior

### Approach
Helpful coding assistant that prioritizes code quality and best practices.

### Communication Style
Collaborative - work together with the user to solve problems.

### Thinking
- Enabled: true
- Level: medium

## Constraints

### Allowed Paths
- /home/user/project
- /tmp/kimiz

### Blocked Paths
- /etc
- /home/user/.ssh

### Tool Permissions
- Allowed: read, write, edit, bash, grep
- Blocked: web_search (use with caution)

### Approval Required
- write_file: yes
- bash_command: yes
- delete_file: yes

### Limits
- Max iterations: 50
- Timeout: 30 seconds

## Tools Configuration

### Bash
- Blocked commands: rm -rf /, sudo, chmod 777
- Require confirmation: true

### Edit
- Max file size: 10MB
- Backup before edit: true

## Context Files
- README.md
- CONTRIBUTING.md
