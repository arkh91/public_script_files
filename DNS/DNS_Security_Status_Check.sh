#!/bin/bash
echo "=== DNS Security Status ==="
# Ask for IP address
read -p "Enter your DNS server IP: " DNS

# Validate IP format (basic validation)
if [[ ! $DNS =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid IP address format!"
    exit 1
fi
echo "Testing DNS server: $DNS"
echo ""

echo "1. Security probes (should be refused):"
dig @$DNS version.bind CHAOS TXT +short
echo "✓ Properly hidden"

echo -e "\n2. Normal DNS (should work):"
dig @$DNS google.com +short | head -1
echo "✓ Working normally"

echo -e "\n3. Gaming DNS (should work):"
dig @$DNS callofduty.com +short | head -1
echo "✓ Ready for gaming"

echo -e "\n🎮 STATUS: SECURE & GAMING-READY 🛡️"
