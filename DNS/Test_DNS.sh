#!/bin/bash
echo "=== Optimized Gaming DNS Test ==="

# Ask for IP address
read -p "Enter your DNS server IP: " YOUR_DNS

# Validate IP format (basic validation)
if [[ ! $YOUR_DNS =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid IP address format!"
    exit 1
fi

echo "Testing DNS server: $YOUR_DNS"
echo ""

TEST_DOMAINS=("activision.com" "callofduty.com" "codmobile.com")

for domain in "${TEST_DOMAINS[@]}"; do
    echo -e "\n=== Testing: $domain ==="
    
    # First query (might be slower)
    echo -n "First query - Your DNS: "
    dig @$YOUR_DNS $domain +stats 2>/dev/null | grep "Query time"
    
    # Second query (should be 0ms if cached)
    echo -n "Cached query - Your DNS: "
    dig @$YOUR_DNS $domain +stats 2>/dev/null | grep "Query time"
    
    # Compare with Cloudflare
    echo -n "Cloudflare DNS: "
    dig @1.1.1.1 $domain +stats 2>/dev/null | grep "Query time"
done


# bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/DNS/Test_DNS.sh)
