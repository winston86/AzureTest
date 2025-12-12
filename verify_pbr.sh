#!/bin/bash

# Configuration
MAPPING_FILE="/tmp/ip_map.txt"
TEST_URL="https://ifconfig.me"

echo "--- Starting Multi-IP Policy-Based Routing Verification ---"
echo "Target URL: $TEST_URL"
echo "Mapping file: $MAPPING_FILE"
echo ""

# Check for PBR integrity
echo "--- 1. PBR Rule Integrity Check ---"
RULE_COUNT=$(grep -c "ip_table_" /etc/iproute2/rt_tables)
if [ $RULE_COUNT -gt 0 ]; then
    echo "SUCCESS: Found $RULE_COUNT custom routing tables in rt_tables."
else
    echo "FAILURE: Custom routing tables not found or missing from rt_tables."
fi

echo "Active 'ip rule show' results (should show rules for all private IPs):"
ip rule show | grep "from 10.0.1"
echo ""

# Initialize counters
SUCCESS_COUNT=0
FAILURE_COUNT=0
FAILURE_LOG=""

# Read the mapping file and test each IP
if [ -f "$MAPPING_FILE" ]; then
    while IFS=: read -r private_ip public_ip; do
        # Skip comments and empty lines
        if [[ $private_ip =~ ^#.* ]] || [[ -z $private_ip ]]; then
            continue
        fi

        echo "Testing Private IP $private_ip (Expected Public IP: $public_ip)..."
        
        # Use curl to get the outbound IP via the specified private interface
        OUTBOUND_IP=$(curl -s --interface "$private_ip" "$TEST_URL" 2>/dev/null)

        if [ "$OUTBOUND_IP" == "$public_ip" ]; then
            echo "  [SUCCESS] Outbound IP matched: $OUTBOUND_IP"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            echo "  [FAILURE] Outbound IP mismatch! Returned: $OUTBOUND_IP (Expected: $public_ip)"
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
            FAILURE_LOG+="- Private $private_ip failed: Returned $OUTBOUND_IP (Expected $public_ip)\n"
        fi
        
    done < "$MAPPING_FILE"
else
    echo "FATAL ERROR: Mapping file $MAPPING_FILE not found."
    exit 1
fi

echo ""
echo "--- Verification Summary ---"
echo "Total IPs Tested: $((SUCCESS_COUNT + FAILURE_COUNT))"
echo "Successful Tests: $SUCCESS_COUNT"
echo "Failed Tests: $FAILURE_COUNT"

if [ $FAILURE_COUNT -eq 0 ]; then
    echo ""
    echo "##################################################"
    echo "### All public IPs are functional and routed correctly. ###"
    echo "##################################################"
    exit 0
else
    echo ""
    echo "##################################################"
    echo "### FAILURE: Not all public IPs are functional. ###"
    echo "##################################################"
    echo -e "\nFailure Details:\n$FAILURE_LOG"
    exit 1
fi