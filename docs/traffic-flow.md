# Traffic flow diagram

This diagram shows the request path after the Terraform resources have been deployed.

```mermaid
flowchart LR
  client["Client"]
  dns["External DNS<br/>app_domain"]
  httpLb["XC HTTP Load Balancer<br/>HTTP listener"]
  originPool["XC Origin Pool"]
  vsite["XC Virtual Site"]

  subgraph site1["Azure CE Site 1"]
    ce1slo["SLO / outside subnet<br/>VIP advertisement / client-facing"]
    ce1["Single-node Azure CE"]
    ce1sli["SLI / inside subnet<br/>origin-facing"]
    ce1slo --> ce1 --> ce1sli
  end

  subgraph site2["Azure CE Site 2"]
    ce2slo["SLO / outside subnet<br/>VIP advertisement / client-facing"]
    ce2["Single-node Azure CE"]
    ce2sli["SLI / inside subnet<br/>origin-facing"]
    ce2slo --> ce2 --> ce2sli
  end

  origin["Private origin application<br/>private_ip or private_name : origin_port"]

  client --> dns --> httpLb
  httpLb --> originPool
  originPool --> vsite

  vsite --> ce1slo
  vsite --> ce2slo
  ce1sli --> origin
  ce2sli --> origin
```

## Traffic sequence

1. A client resolves `app_domain` using external DNS.
2. The client connects to the XC HTTP load balancer listener.
3. The load balancer selects the configured XC origin pool.
4. The origin pool targets the XC Virtual Site.
5. The Virtual Site selects one of the labeled Azure CE sites.
6. Traffic is advertised toward the selected CE site's `SLO` outside interface.
7. The CE forwards the request out its `SLI` inside interface.
8. The private origin application receives the request on `origin_port`.

## Notes

- This diagram represents request traffic, not Terraform resource creation order.
- The repository does not deploy the origin application; it only points to the private backend defined by `origin_server_type` and `origin_server_value`.
- Management connectivity over the Secure Mesh public IP is intentionally omitted here because it is not in the application data path.
