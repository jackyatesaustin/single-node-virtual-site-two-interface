# Traffic flow diagram

This diagram shows the request paths after the Terraform resources have been deployed. In the default configuration, the same HTTP load balancer is advertised on both the CE inside and outside networks. Optional Azure public and internal load balancers can front those CE interfaces.

```mermaid
flowchart LR
  extClient["External client"]
  extDns["External DNS<br/>app_domain"]
  intClient["Internal client"]
  intDns["Internal DNS<br/>app_domain or internal app record"]
  publicLb["Optional Azure public load balancer<br/>fronts CE SLO IPs"]
  internalLb["Optional Azure internal load balancer<br/>fronts CE SLI IPs"]
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

  extClient --> extDns --> publicLb --> httpLb
  intClient --> intDns --> internalLb --> httpLb
  httpLb --> originPool
  originPool --> vsite

  vsite --> ce1slo
  vsite --> ce2slo
  vsite --> ce1sli
  vsite --> ce2sli
  ce1sli --> origin
  ce2sli --> origin
```

## External traffic sequence

1. An external client resolves `app_domain` using external DNS.
2. The external client connects either directly to the advertised CE outside VIP or through the optional Azure public load balancer.
3. The load balancer selects the configured XC origin pool.
4. The origin pool targets the XC Virtual Site.
5. The Virtual Site selects one of the labeled Azure CE sites.
6. Traffic is advertised toward the selected CE site's `SLO` outside interface.
7. The CE forwards the request out its `SLI` inside interface.
8. The private origin application receives the request on `origin_port`.

## Internal traffic sequence

1. An internal client resolves the application name using internal DNS.
2. The internal client connects either directly to the advertised CE inside VIP or through the optional Azure internal load balancer.
3. The load balancer selects the configured XC origin pool.
4. The origin pool targets the XC Virtual Site.
5. The Virtual Site selects one of the labeled Azure CE sites.
6. Traffic is advertised toward the selected CE site's `SLI` inside interface.
7. The CE forwards the request to the private origin application on `origin_port`.

## Notes

- This diagram represents request traffic, not Terraform resource creation order.
- The repository does not deploy the origin application; it only points to the private backend defined by `origin_server_type` and `origin_server_value`.
- Management connectivity over the Secure Mesh public IP is intentionally omitted here because it is not in the application data path.
- Azure public and internal load balancers are optional resources in this Terraform. When enabled, the public LB backs onto the CE `SLO` addresses and the internal LB backs onto the CE `SLI` addresses.
- Backend CE IPs are auto-discovered from Azure NICs by subnet membership when possible. If your deployment uses nonstandard addressing or multiple matching NICs, set the explicit backend IP override lists in `ce_sites`.
