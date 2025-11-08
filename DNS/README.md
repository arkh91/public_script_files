
```markdown
```mermaid
flowchart TD
    C[Client: Intra/Browser] -->|HTTPS /dns-query<br>(binary DNS query)| P[Node.js DoH Proxy]
    P -->|UDP DNS query| U[Unbound<br>(127.0.0.1:53)]
    U -->|binary DNS response| P
    P -->|HTTPS response<br>(application/dns-message)| C
    C -->|Receives DNS answer| C

bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/DNS/DNS_doHGame_installed.sh)
bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/DNS/Test_DNS.sh)
bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/DNS/DNS_Security_Status_Check.sh) #Weekly run
bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/DNS/DNS_Enhanced_Security_Status_Check.sh)
