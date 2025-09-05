🔁 Visual Flow (Simplified)
[Client: Intra/Browser]
        |
        | HTTPS request (/dns-query, binary DNS query)
        v
[Node.js DoH Proxy] --- UDP ---> [Unbound (127.0.0.1:53)]
        |                             |
        | <--- binary DNS response ---|
        v
   HTTPS response (application/dns-message)
        |
        v
[Client receives DNS answer]
