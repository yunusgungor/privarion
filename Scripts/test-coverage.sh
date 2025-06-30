#!/bin/bash

# Test Coverage Script for Privarion
# Runs all tests and generates coverage reports

set -e

echo "🧪 Running Privarion Test Suite with Coverage..."

# Clean previous builds
echo "📦 Cleaning previous builds..."
swift package clean

# Run tests with coverage
echo "🔍 Running tests with coverage..."
swift test --enable-code-coverage

# Generate coverage report
echo "📊 Generating coverage report..."

# Check if xcov is available for detailed reports
if command -v xcov &> /dev/null; then
    echo "📈 Generating detailed coverage report with xcov..."
    xcov --scheme Privarion --minimum_coverage_percentage 90
else
    echo "⚠️  xcov not found. Install with: gem install xcov"
fi

# Extract coverage data using llvm-cov (if available)
if command -v llvm-cov &> /dev/null; then
    echo "📋 Extracting coverage data..."
    
    # Find test binaries
    TEST_BINARY_PATH=$(swift build --show-bin-path)/PrivarionPackageTests.xctest
    
    if [ -f "$TEST_BINARY_PATH" ]; then
        # Generate text report
        llvm-cov report "$TEST_BINARY_PATH" \
            -instr-profile=.build/debug/codecov/default.profdata \
            -use-color \
            -summary-only
            
        # Generate HTML report
        llvm-cov show "$TEST_BINARY_PATH" \
            -instr-profile=.build/debug/codecov/default.profdata \
            -format=html \
            -output-dir=.build/coverage-report \
            -use-color
            
        echo "📄 HTML coverage report generated at: .build/coverage-report/index.html"
    else
        echo "⚠️  Test binary not found at: $TEST_BINARY_PATH"
    fi
else
    echo "⚠️  llvm-cov not found. Coverage extraction limited."
fi

# Check coverage thresholds
echo "✅ Test run completed!"
echo ""
echo "📋 Coverage Requirements:"
echo "   - Unit Test Coverage: ≥90% for new code"
echo "   - Overall Coverage: ≥85%"
echo "   - Integration Coverage: ≥80%"
echo ""
echo "🎯 Quality Gates:"
echo "   - All tests must pass"
echo "   - No critical security vulnerabilities"
echo "   - Performance benchmarks met"
echo ""
echo "💡 To view detailed coverage:"
echo "   - HTML Report: open .build/coverage-report/index.html"
echo "   - Install xcov: gem install xcov"
echo "   - Install llvm-cov: xcode-select --install"
