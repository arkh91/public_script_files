
```markdown
```mermaid
flowchart TD
    C[Client: Intra/Browser] -->|HTTPS /dns-query<br>(binary DNS query)| P[Node.js DoH Proxy]
    P -->|UDP DNS query| U[Unbound<br>(127.0.0.1:53)]
    U -->|binary DNS response| P
    P -->|HTTPS response<br>(application/dns-message)| C
    C -->|Receives DNS answer| C
