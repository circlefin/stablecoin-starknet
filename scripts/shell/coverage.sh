# Copyright 2025 Circle Internet Group, Inc. All rights reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#!/bin/bash

set -e

LINE_COVERAGE_THRESHOLD=60
FUNCTION_COVERAGE_THRESHOLD=60

echo "🔍 Running coverage analysis..."

# 0. Cleanup all coverage files
rm -rf coverage/combined_coverage.lcov
rm -rf coverage/html
for file in $(find packages -name "coverage.lcov" -path "*/coverage/*" 2>/dev/null); do
    rm $file
done

# 1. Run tests with coverage
echo "Running tests with coverage..."
snforge test --workspace --coverage

# 2. Combine all coverage.lcov files
echo "Combining coverage files..."
mkdir -p coverage

# Find all coverage files and combine them
COVERAGE_FILES=""
for file in $(find packages -name "coverage.lcov" -path "*/coverage/*" 2>/dev/null); do
    if [ -f "$file" ]; then
        COVERAGE_FILES="$COVERAGE_FILES --add-tracefile $file"
    fi
done

if [ -z "$COVERAGE_FILES" ]; then
    echo "❌ No coverage files found!"
    exit 1
fi

lcov $COVERAGE_FILES --output-file coverage/combined_coverage.lcov --ignore-errors range

# 3. Generate HTML report with omitted lines
echo "Generating HTML report..."
genhtml coverage/combined_coverage.lcov \
    --output-directory coverage/html \
    --ignore-errors range

# 4. Check coverage rate is 100%
echo "Checking coverage requirements..."
LINE_COVERAGE=$(lcov --summary coverage/combined_coverage.lcov 2>/dev/null | grep "lines" | grep -o '[0-9.]*%' | head -1 | sed 's/%//')
FUNCTION_COVERAGE=$(lcov --summary coverage/combined_coverage.lcov 2>/dev/null | grep "functions" | grep -o '[0-9.]*%' | head -1 | sed 's/%//')

echo "Line coverage: ${LINE_COVERAGE}%"
echo "Function coverage: ${FUNCTION_COVERAGE}%"

if (( $(echo "$LINE_COVERAGE < $LINE_COVERAGE_THRESHOLD" | bc -l) )) || (( $(echo "$FUNCTION_COVERAGE < $FUNCTION_COVERAGE_THRESHOLD" | bc -l) )); then
    echo "❌ Coverage is ${LINE_COVERAGE}% for lines and ${FUNCTION_COVERAGE}% for functions, but ${LINE_COVERAGE_THRESHOLD}% is required for lines and ${FUNCTION_COVERAGE_THRESHOLD}% is required for functions!"
    echo "📊 View detailed report: coverage/html/index.html"
    exit 1
else
    echo "✅ Coverage requirement met: ${LINE_COVERAGE}% for lines and ${FUNCTION_COVERAGE}% for functions"
    echo "📊 Report generated: coverage/html/index.html"
fi
