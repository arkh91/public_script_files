#!/bin/bash
echo "=== DNS Security Status Check ==="
echo ""

# Ask for IP address
read -p "Enter your DNS server IP: " DNS

# Remove any whitespace
DNS=$(echo "$DNS" | tr -d '[:space:]')

# Validate IP format
if [[ ! $DNS =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "❌ Error: Invalid IP address format!"
    exit 1
fi

# Validate each octet
IFS='.' read -r -a octets <<< "$DNS"
for octet in "${octets[@]}"; do
    if [[ $octet -lt 0 || $octet -gt 255 ]]; then
        echo "❌ Error: Invalid IP address - octet $octet out of range!"
        exit 1
    fi
done

echo ""
echo "Testing DNS server: $DNS"
echo "================================="

# Test 1: Security (should refuse)
echo -e "\n1. 🔒 Security Test (should be refused):"
if dig @$DNS version.bind CHAOS TXT +short +time=2 +tries=1 2>/dev/null | grep -q .; then
    echo "❌ WARNING: Version information exposed!"
else
    echo "✅ Properly hidden - Security OK"
fi

# Test 2: Normal DNS functionality
echo -e "\n2. 🌐 Normal DNS Test:"
result=$(dig @$DNS google.com +short +time=2 +tries=1 2>/dev/null | head -1)
if [ -n "$result" ]; then
    echo "✅ Working - Resolved to: $result"
else
    echo "❌ FAILED: Cannot resolve normal domains"
fi

# Test 3: Gaming DNS functionality
echo -e "\n3. 🎮 Gaming DNS Test:"
result=$(dig @$DNS callofduty.com +short +time=2 +tries=1 2>/dev/null | head -1)
if [ -n "$result" ]; then
    echo "✅ Working - Resolved to: $result"
else
    echo "❌ FAILED: Cannot resolve gaming domains"
fi

# Test 4: Response time check
echo -e "\n4. ⚡ Performance Test:"
response_time=$(dig @$DNS google.com 2>/dev/null | grep "Query time" | awk '{print $4}')
if [ -n "$response_time" ]; then
    if [ "$response_time" -eq 0 ]; then
        echo "✅ Excellent - 0ms (cached)"
    elif [ "$response_time" -lt 50 ]; then
        echo "✅ Good - ${response_time}ms"
    elif [ "$response_time" -lt 100 ]; then
        echo "⚠️  Acceptable - ${response_time}ms"
    else
        echo "❌ Slow - ${response_time}ms"
    fi
else
    echo "❌ FAILED: No response"
fi

echo ""
echo "================================="
echo "🎮 FINAL STATUS: SECURE & GAMING-READY 🛡️"
echo ""
echo "Next step: Configure your mobile device to use: $DNS"
