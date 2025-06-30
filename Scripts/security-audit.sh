#!/bin/bash

# Privarion Security Audit Script
# Comprehensive security analysis for macOS Swift/C application
# Based on OWASP guidelines for desktop application security

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Audit configuration
AUDIT_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
AUDIT_DIR="Security/audit_reports"
REPORT_FILE="$AUDIT_DIR/security_audit_$AUDIT_DATE.json"
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Critical, High, Medium, Low counters
CRITICAL_COUNT=0
HIGH_COUNT=0
MEDIUM_COUNT=0
LOW_COUNT=0

echo -e "${BLUE}🔐 Privarion Security Audit - $AUDIT_DATE${NC}"
echo "Workspace: $WORKSPACE_ROOT"
echo "Report: $REPORT_FILE"
echo ""

# Create audit directory
mkdir -p "$AUDIT_DIR"

# Initialize JSON report
cat > "$REPORT_FILE" << EOF
{
  "audit_metadata": {
    "project": "Privarion",
    "audit_date": "$AUDIT_DATE",
    "auditor": "privarion_security_audit_v1.0",
    "workspace_root": "$WORKSPACE_ROOT",
    "owasp_compliance": "OWASP-MASVS-2.0"
  },
  "vulnerabilities": [],
  "summary": {
    "total_files_scanned": 0,
    "critical_issues": 0,
    "high_issues": 0,
    "medium_issues": 0,
    "low_issues": 0,
    "scan_duration_seconds": 0
  }
}
EOF

START_TIME=$(date +%s)

# Function to add vulnerability to report
add_vulnerability() {
    local severity="$1"
    local title="$2"
    local file="$3"
    local line="$4"
    local description="$5"
    local cwe="$6"
    local recommendation="$7"
    
    case "$severity" in
        "CRITICAL") ((CRITICAL_COUNT++)) ;;
        "HIGH") ((HIGH_COUNT++)) ;;
        "MEDIUM") ((MEDIUM_COUNT++)) ;;
        "LOW") ((LOW_COUNT++)) ;;
    esac
    
    # Add to JSON report (simplified - would use jq in production)
    echo -e "${RED}[$severity]${NC} $title"
    echo "  File: $file:$line"
    echo "  $description"
    echo "  CWE: $cwe"
    echo "  Fix: $recommendation"
    echo ""
}

echo -e "${BLUE}📁 Scanning Source Files...${NC}"

# Count files for progress
TOTAL_FILES=$(find "$WORKSPACE_ROOT/Sources" -name "*.swift" -o -name "*.c" -o -name "*.h" | wc -l | tr -d ' ')
echo "Total files to scan: $TOTAL_FILES"
echo ""

# 1. C/C++ Security Analysis
echo -e "${BLUE}🔍 C/C++ Security Analysis${NC}"

if [ -f "$WORKSPACE_ROOT/Sources/PrivarionHook/privarion_hook.c" ]; then
    echo "Scanning privarion_hook.c..."
    
    # Check for buffer overflow in hooked_gethostname
    if grep -n "strcpy(name, g_config_data.hostname)" "$WORKSPACE_ROOT/Sources/PrivarionHook/privarion_hook.c" > /dev/null; then
        add_vulnerability "CRITICAL" "Buffer Overflow in hooked_gethostname()" \
            "Sources/PrivarionHook/privarion_hook.c" "39" \
            "strcpy() used without bounds checking after insufficient length validation. Can cause buffer overflow." \
            "CWE-120" \
            "Replace strcpy() with strncpy() or strlcpy() with proper bounds checking"
    fi
    
    # Check for use of unsafe string functions
    while read -r line_info; do
        line_num=$(echo "$line_info" | cut -d: -f1)
        add_vulnerability "HIGH" "Unsafe String Function Usage" \
            "Sources/PrivarionHook/privarion_hook.c" "$line_num" \
            "Use of potentially unsafe string function that may not null-terminate strings." \
            "CWE-134" \
            "Use safer alternatives like strlcpy() or implement explicit null termination"
    done < <(grep -n "strcpy\|strcat\|sprintf" "$WORKSPACE_ROOT/Sources/PrivarionHook/privarion_hook.c" 2>/dev/null || true)
    
    # Check for race conditions with global state
    if grep -n "g_config_data\." "$WORKSPACE_ROOT/Sources/PrivarionHook/privarion_hook.c" | grep -v "pthread_mutex" > /dev/null; then
        add_vulnerability "MEDIUM" "Potential Race Condition" \
            "Sources/PrivarionHook/privarion_hook.c" "Multiple" \
            "Global state modification without proper mutex protection may cause race conditions." \
            "CWE-362" \
            "Protect all global state access with pthread_mutex_lock/unlock"
    fi
fi

# 2. Swift Security Analysis
echo -e "${BLUE}🔍 Swift Security Analysis${NC}"

# Check for hardcoded paths
while read -r file; do
    while read -r line_info; do
        line_num=$(echo "$line_info" | cut -d: -f1)
        content=$(echo "$line_info" | cut -d: -f2-)
        add_vulnerability "HIGH" "Hardcoded System Path" \
            "$file" "$line_num" \
            "Hardcoded system path creates security risk if attacker controls the path: $content" \
            "CWE-426" \
            "Use configurable paths, validate existence, and implement path traversal protection"
    done < <(grep -n '"/usr/\|"/System/\|"/Library/' "$file" 2>/dev/null || true)
done < <(find "$WORKSPACE_ROOT/Sources" -name "*.swift")

# Check for dangerous commands in whitelist
if [ -f "$WORKSPACE_ROOT/Sources/PrivarionCore/SystemCommandExecutor.swift" ]; then
    if grep -n '"sudo"' "$WORKSPACE_ROOT/Sources/PrivarionCore/SystemCommandExecutor.swift" > /dev/null; then
        add_vulnerability "CRITICAL" "Dangerous Command in Whitelist" \
            "Sources/PrivarionCore/SystemCommandExecutor.swift" "56" \
            "sudo command in whitelist allows privilege escalation attacks." \
            "CWE-269" \
            "Remove sudo from whitelist or implement strict argument validation and user confirmation"
    fi
    
    if grep -n '"launchctl"' "$WORKSPACE_ROOT/Sources/PrivarionCore/SystemCommandExecutor.swift" > /dev/null; then
        add_vulnerability "HIGH" "System Service Manipulation" \
            "Sources/PrivarionCore/SystemCommandExecutor.swift" "57" \
            "launchctl allows manipulation of system services which could be exploited." \
            "CWE-250" \
            "Remove launchctl or implement strict argument filtering"
    fi
fi

# Check for process execution without input validation
while read -r file; do
    while read -r line_info; do
        line_num=$(echo "$line_info" | cut -d: -f1)
        add_vulnerability "HIGH" "Unvalidated Process Execution" \
            "$file" "$line_num" \
            "Process arguments not validated, potential command injection vector." \
            "CWE-78" \
            "Implement argument sanitization and validation before process execution"
    done < <(grep -n "process.arguments.*arguments" "$file" 2>/dev/null || true)
done < <(find "$WORKSPACE_ROOT/Sources" -name "*.swift")

# 3. Privilege Escalation Analysis
echo -e "${BLUE}🔍 Privilege Escalation Analysis${NC}"

# Check for DYLD injection patterns
while read -r file; do
    if grep -q "DYLD_INSERT_LIBRARIES\|dylib" "$file"; then
        add_vulnerability "HIGH" "Dynamic Library Injection" \
            "$file" "Multiple" \
            "DYLD injection capability could be exploited for privilege escalation." \
            "CWE-114" \
            "Implement signature verification for injected libraries and restrict injection scope"
    fi
done < <(find "$WORKSPACE_ROOT/Sources" -name "*.swift")

# 4. Memory Safety Analysis
echo -e "${BLUE}🔍 Memory Safety Analysis${NC}"

# Check for force unwrapping
while read -r file; do
    while read -r line_info; do
        line_num=$(echo "$line_info" | cut -d: -f1)
        add_vulnerability "MEDIUM" "Force Unwrapping" \
            "$file" "$line_num" \
            "Force unwrapping can cause crashes if value is nil." \
            "CWE-476" \
            "Use safe unwrapping with guard/if let or nil coalescing"
    done < <(grep -n '!' "$file" | grep -v '!=' | grep -v '!(' 2>/dev/null || true)
done < <(find "$WORKSPACE_ROOT/Sources" -name "*.swift")

# 5. Cryptographic Analysis
echo -e "${BLUE}🔍 Cryptographic Analysis${NC}"

# Check for weak random number generation
while read -r file; do
    while read -r line_info; do
        line_num=$(echo "$line_info" | cut -d: -f1)
        add_vulnerability "MEDIUM" "Weak Random Number Generation" \
            "$file" "$line_num" \
            "arc4random() may not be cryptographically secure for all use cases." \
            "CWE-338" \
            "Use SecRandomCopyBytes() for cryptographic purposes"
    done < <(grep -n "arc4random\|random()" "$file" 2>/dev/null || true)
done < <(find "$WORKSPACE_ROOT/Sources" -name "*.swift")

# 6. File System Security
echo -e "${BLUE}🔍 File System Security${NC}"

# Check for insecure file operations
while read -r file; do
    while read -r line_info; do
        line_num=$(echo "$line_info" | cut -d: -f1)
        add_vulnerability "MEDIUM" "Insecure File Operation" \
            "$file" "$line_num" \
            "File operations without proper permission/existence checks." \
            "CWE-22" \
            "Implement path traversal protection and file permission validation"
    done < <(grep -n "FileManager.*createFile\|FileManager.*copyItem" "$file" 2>/dev/null || true)
done < <(find "$WORKSPACE_ROOT/Sources" -name "*.swift")

# Calculate scan duration
END_TIME=$(date +%s)
SCAN_DURATION=$((END_TIME - START_TIME))

# Update summary in JSON report
cat > "$REPORT_FILE" << EOF
{
  "audit_metadata": {
    "project": "Privarion",
    "audit_date": "$AUDIT_DATE",
    "auditor": "privarion_security_audit_v1.0",
    "workspace_root": "$WORKSPACE_ROOT",
    "owasp_compliance": "OWASP-MASVS-2.0"
  },
  "summary": {
    "total_files_scanned": $TOTAL_FILES,
    "critical_issues": $CRITICAL_COUNT,
    "high_issues": $HIGH_COUNT,
    "medium_issues": $MEDIUM_COUNT,
    "low_issues": $LOW_COUNT,
    "scan_duration_seconds": $SCAN_DURATION
  },
  "recommendations": [
    "Address all CRITICAL vulnerabilities immediately",
    "Implement input validation and sanitization",
    "Use secure coding practices for C/Swift interop",
    "Regular security audits and penetration testing",
    "Implement runtime security monitoring"
  ]
}
EOF

# Print summary
echo -e "${BLUE}📊 Security Audit Summary${NC}"
echo "Files Scanned: $TOTAL_FILES"
echo -e "Critical Issues: ${RED}$CRITICAL_COUNT${NC}"
echo -e "High Issues: ${YELLOW}$HIGH_COUNT${NC}" 
echo -e "Medium Issues: ${YELLOW}$MEDIUM_COUNT${NC}"
echo -e "Low Issues: $LOW_COUNT"
echo "Scan Duration: ${SCAN_DURATION}s"
echo ""

# OWASP Compliance Check
TOTAL_ISSUES=$((CRITICAL_COUNT + HIGH_COUNT))
if [ $CRITICAL_COUNT -eq 0 ] && [ $HIGH_COUNT -le 2 ]; then
    echo -e "${GREEN}✅ OWASP Compliance: PASSED${NC}"
    echo "Zero critical vulnerabilities, ≤2 high-severity issues"
else
    echo -e "${RED}❌ OWASP Compliance: FAILED${NC}"
    echo "Requirement: Zero critical vulnerabilities, ≤2 high-severity issues"
    echo "Current: $CRITICAL_COUNT critical, $HIGH_COUNT high"
fi

echo ""
echo "Full report saved to: $REPORT_FILE"
echo -e "${BLUE}Security audit completed.${NC}"

# Exit with error code if critical issues found
if [ $CRITICAL_COUNT -gt 0 ]; then
    exit 1
fi
