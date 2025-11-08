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
    your_time1=$(dig @$YOUR_DNS $domain +stats 2>/dev/null | grep "Query time" | awk '{print $4}')
    echo "${your_time1} ms"
    
    # Second query (should be 0ms if cached)
    echo -n "Cached query - Your DNS: "
    your_time2=$(dig @$YOUR_DNS $domain +stats 2>/dev/null | grep "Query time" | awk '{print $4}')
    echo "${your_time2} ms"
    your_dns_times+=($your_time1 $your_time2)
    
    # Compare with Cloudflare
    echo -n "Cloudflare DNS: "
    cf_time=$(dig @1.1.1.1 $domain +stats 2>/dev/null | grep "Query time" | awk '{print $4}')
    echo "${cf_time} ms"
    cloudflare_times+=($cf_time)
    
    # Compare with Google DNS
    echo -n "Google DNS: "
    google_time=$(dig @8.8.8.8 $domain +stats 2>/dev/null | grep "Query time" | awk '{print $4}')
    echo "${google_time} ms"
    google_times+=($google_time)
done

# Calculate averages
echo -e "\n=== Average Performance ==="
google_avg=$(echo "${google_times[@]}" | awk '{sum=0; for(i=1;i<=NF;i++) sum+=$i; print sum/NF}')
cloudflare_avg=$(echo "${cloudflare_times[@]}" | awk '{sum=0; for(i=1;i<=NF;i++) sum+=$i; print sum/NF}')
your_dns_avg=$(echo "${your_dns_times[@]}" | awk '{sum=0; for(i=1;i<=NF;i++) sum+=$i; print sum/NF}')

echo "This DNS ($YOUR_DNS): ${your_dns_avg} ms average"
echo "Google DNS (8.8.8.8): ${google_avg} ms average"
echo "Cloudflare DNS (1.1.1.1): ${cloudflare_avg} ms average"


# bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/DNS/Test_DNS.sh)
