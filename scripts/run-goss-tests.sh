#!/usr/bin/env bash
# ==============================================================================
# Automated Security & Compliance Test Runner using Goss
# Validates CIS Benchmark Hardening, Services, Packages, and Sysctl rules
# ==============================================================================
set -euo pipefail

echo "======================================================================"
echo " Starting Automated Golden Image Compliance Validation (Goss)        "
echo "======================================================================"

if [[ "${ENABLE_TESTING:-true}" != "true" ]]; then
    echo "==> Automated testing is disabled via configuration. Skipping tests."
    exit 0
fi

TEST_DIR="${TEST_DIR:-/tmp/goss-tests}"
GOSS_FILE="${TEST_DIR}/goss.yaml"

if [[ ! -f "${GOSS_FILE}" ]]; then
    echo "ERROR: Goss test file not found at ${GOSS_FILE}"
    exit 1
fi

echo "==> Running Goss validation suite against target image..."
echo "==> Test specification: ${GOSS_FILE}"

# Run Goss with detailed output format
if goss -g "${GOSS_FILE}" validate --format documentation; then
    echo "======================================================================"
    echo " [PASS] All security and configuration tests passed successfully!     "
    echo "======================================================================"
else
    echo "======================================================================"
    echo " [FAIL] Image validation failed! One or more tests did not meet spec. "
    echo " Rejecting image build to prevent insecure deployment.                "
    echo "======================================================================"
    exit 1
fi

# Clean up test artifacts
rm -rf "${TEST_DIR}"
