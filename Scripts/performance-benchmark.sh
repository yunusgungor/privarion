#!/bin/bash

# Performance Benchmark Runner Script
# Based on Context7 performance testing best practices
# Automated performance regression testing for Privarion

set -euo pipefail

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="${PROJECT_DIR}/benchmark-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="${RESULTS_DIR}/benchmark_report_${TIMESTAMP}.json"
BASELINE_FILE="${RESULTS_DIR}/performance_baseline.json"
LOG_FILE="${RESULTS_DIR}/benchmark_${TIMESTAMP}.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Setup benchmark environment
setup_benchmark() {
    log "Setting up benchmark environment..."
    
    # Create results directory
    mkdir -p "$RESULTS_DIR"
    
    # Initialize log file
    echo "Privarion Performance Benchmark - $(date)" > "$LOG_FILE"
    echo "=====================================" >> "$LOG_FILE"
    
    # Check if we're in the right directory
    if [[ ! -f "${PROJECT_DIR}/Package.swift" ]]; then
        error "Package.swift not found. Are you in the Privarion project directory?"
        exit 1
    fi
    
    # Clean previous build artifacts
    log "Cleaning build artifacts..."
    swift package clean
    
    success "Benchmark environment setup complete"
}

# Build project for benchmarking
build_project() {
    log "Building project for performance testing..."
    
    # Build in release mode for accurate performance measurements
    if swift build -c release; then
        success "Project built successfully in release mode"
    else
        error "Failed to build project"
        exit 1
    fi
}

# Run performance benchmarks
run_benchmarks() {
    log "Running performance benchmarks..."
    
    # Run the performance benchmark tests
    log "Executing PerformanceBenchmarkTests..."
    
    if swift test --filter PerformanceBenchmarkTests --configuration release; then
        success "Performance benchmarks completed successfully"
    else
        error "Performance benchmarks failed"
        return 1
    fi
    
    # Collect benchmark results from temp files
    collect_benchmark_results
}

# Collect benchmark results from temporary files
collect_benchmark_results() {
    log "Collecting benchmark results..."
    
    local temp_results=()
    local temp_files=(/tmp/privarion_benchmark_*.json)
    
    if [[ ${#temp_files[@]} -eq 0 ]] || [[ ! -f "${temp_files[0]}" ]]; then
        warning "No benchmark result files found in /tmp/"
        return 0
    fi
    
    # Combine all benchmark results
    echo "{" > "$REPORT_FILE"
    echo "  \"benchmark_run\": {" >> "$REPORT_FILE"
    echo "    \"timestamp\": \"$(date -Iseconds)\"," >> "$REPORT_FILE"
    echo "    \"project\": \"Privarion\"," >> "$REPORT_FILE"
    echo "    \"version\": \"$(git describe --tags --always 2>/dev/null || echo 'unknown')\"," >> "$REPORT_FILE"
    echo "    \"commit\": \"$(git rev-parse HEAD 2>/dev/null || echo 'unknown')\"," >> "$REPORT_FILE"
    echo "    \"system\": {" >> "$REPORT_FILE"
    echo "      \"os\": \"$(uname -s)\"," >> "$REPORT_FILE"
    echo "      \"arch\": \"$(uname -m)\"," >> "$REPORT_FILE"
    echo "      \"swift_version\": \"$(swift --version | head -n1)\"" >> "$REPORT_FILE"
    echo "    }," >> "$REPORT_FILE"
    echo "    \"results\": [" >> "$REPORT_FILE"
    
    local first=true
    for result_file in "${temp_files[@]}"; do
        if [[ -f "$result_file" ]]; then
            if [[ "$first" == true ]]; then
                first=false
            else
                echo "," >> "$REPORT_FILE"
            fi
            
            # Extract just the results array from each file
            jq -c '.results[]' "$result_file" 2>/dev/null >> "$REPORT_FILE" || {
                warning "Failed to process $result_file"
            }
            
            # Clean up temporary file
            rm -f "$result_file"
        fi
    done
    
    echo "" >> "$REPORT_FILE"
    echo "    ]" >> "$REPORT_FILE"
    echo "  }" >> "$REPORT_FILE"
    echo "}" >> "$REPORT_FILE"
    
    success "Benchmark results collected in $REPORT_FILE"
}

# Generate performance report
generate_report() {
    log "Generating performance report..."
    
    if [[ ! -f "$REPORT_FILE" ]]; then
        error "No benchmark results file found"
        return 1
    fi
    
    # Extract summary statistics
    local total_tests=$(jq '.benchmark_run.results | length' "$REPORT_FILE" 2>/dev/null || echo "0")
    local passed_tests=$(jq '[.benchmark_run.results[] | select(.status == "PASSED")] | length' "$REPORT_FILE" 2>/dev/null || echo "0")
    local failed_tests=$(jq '[.benchmark_run.results[] | select(.status == "FAILED")] | length' "$REPORT_FILE" 2>/dev/null || echo "0")
    local timeout_tests=$(jq '[.benchmark_run.results[] | select(.status == "TIMEOUT")] | length' "$REPORT_FILE" 2>/dev/null || echo "0")
    
    # Calculate averages
    local avg_duration=$(jq '[.benchmark_run.results[].duration] | add / length' "$REPORT_FILE" 2>/dev/null || echo "0")
    local avg_memory=$(jq '[.benchmark_run.results[].metrics.memoryUsageMB] | add / length' "$REPORT_FILE" 2>/dev/null || echo "0")
    local avg_cpu=$(jq '[.benchmark_run.results[].metrics.cpuUsage] | add / length' "$REPORT_FILE" 2>/dev/null || echo "0")
    
    # Print summary
    echo ""
    echo "======================================"
    echo "    PERFORMANCE BENCHMARK SUMMARY"
    echo "======================================"
    echo "Total Tests:     $total_tests"
    echo "Passed:          $passed_tests"
    echo "Failed:          $failed_tests"  
    echo "Timeouts:        $timeout_tests"
    echo "Success Rate:    $(echo "scale=1; $passed_tests * 100 / $total_tests" | bc 2>/dev/null || echo "N/A")%"
    echo ""
    echo "Average Duration: ${avg_duration}ms"
    echo "Average Memory:   ${avg_memory}MB"
    echo "Average CPU:      ${avg_cpu}%"
    echo "======================================"
    echo ""
    
    success "Performance report generated: $REPORT_FILE"
}

# Check for performance regressions
check_regressions() {
    log "Checking for performance regressions..."
    
    if [[ ! -f "$BASELINE_FILE" ]]; then
        warning "No baseline file found. Creating new baseline from current results."
        cp "$REPORT_FILE" "$BASELINE_FILE"
        return 0
    fi
    
    # Compare with baseline (simplified comparison)
    local current_avg_duration=$(jq '[.benchmark_run.results[].duration] | add / length' "$REPORT_FILE" 2>/dev/null || echo "0")
    local baseline_avg_duration=$(jq '[.benchmark_run.results[].duration] | add / length' "$BASELINE_FILE" 2>/dev/null || echo "0")
    
    local duration_increase=$(echo "scale=2; ($current_avg_duration - $baseline_avg_duration) / $baseline_avg_duration * 100" | bc 2>/dev/null || echo "0")
    
    if (( $(echo "$duration_increase > 20" | bc -l 2>/dev/null) )); then
        error "Performance regression detected! Duration increased by ${duration_increase}%"
        return 1
    elif (( $(echo "$duration_increase > 10" | bc -l 2>/dev/null) )); then
        warning "Performance degradation detected: Duration increased by ${duration_increase}%"
    else
        success "No significant performance regression detected"
    fi
    
    return 0
}

# Update baseline if requested
update_baseline() {
    if [[ "${1:-}" == "--update-baseline" ]]; then
        log "Updating performance baseline..."
        cp "$REPORT_FILE" "$BASELINE_FILE"
        success "Baseline updated: $BASELINE_FILE"
    fi
}

# Cleanup function
cleanup() {
    log "Cleaning up temporary files..."
    rm -f /tmp/privarion_benchmark_*.json 2>/dev/null || true
}

# Main execution
main() {
    local update_baseline_flag=""
    
    # Parse arguments
    for arg in "$@"; do
        case $arg in
            --update-baseline)
                update_baseline_flag="--update-baseline"
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--update-baseline] [--help]"
                echo ""
                echo "Options:"
                echo "  --update-baseline  Update the performance baseline with current results"
                echo "  --help, -h        Show this help message"
                exit 0
                ;;
        esac
    done
    
    log "Starting Privarion performance benchmark suite..."
    
    # Trap cleanup on exit
    trap cleanup EXIT
    
    # Run benchmark pipeline
    setup_benchmark
    build_project
    
    if run_benchmarks; then
        generate_report
        
        if check_regressions; then
            update_baseline "$update_baseline_flag"
            success "Performance benchmark completed successfully!"
            exit 0
        else
            error "Performance regressions detected!"
            exit 1
        fi
    else
        error "Benchmark execution failed!"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
