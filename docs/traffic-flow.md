# Traffic flow diagram

This diagram shows the request paths after the Terraform resources have been deployed. Each application gets its own XC HTTP load balancer and origin pool. Internal applications advertise on `SLI`, external applications advertise on `SLO`, and dual-network applications can advertise on both. The XC Virtual Site is shown as a logical grouping of CE sites, not as a separate data-plane hop.

```mermaid
flowchart LR
  extClient["External client"]
  extDns["External DNS"]
  intClient["Internal client"]
  intDns["Internal DNS"]
  publicLb["Optional Azure public load balancer<br/>fronts CE SLO IPs"]
  internalLb["Optional Azure internal load balancer<br/>fronts CE SLI IPs"]
  extApp["XC HTTP LB: public app<br/>advertise = SITE_NETWORK_OUTSIDE"]
  dualApp["XC HTTP LB: shared app<br/>advertise = SITE_NETWORK_INSIDE_AND_OUTSIDE"]
  intApp["XC HTTP LB: internal app<br/>advertise = SITE_NETWORK_INSIDE"]
  extPool["Origin Pool: public app"]
  dualPool["Origin Pool: shared app"]
  intPool["Origin Pool: internal app"]
  vsite["XC Virtual Site<br/>logical grouping of CE Site 1 + CE Site 2"]

  subgraph site1["Azure CE Site 1"]
    ce1slo["SLO / outside subnet<br/>external listeners"]
    ce1["Single-node Azure CE"]
    ce1sli["SLI / inside subnet<br/>internal listeners and origins"]
    ce1slo --> ce1 --> ce1sli
  end

  subgraph site2["Azure CE Site 2"]
    ce2slo["SLO / outside subnet<br/>external listeners"]
    ce2["Single-node Azure CE"]
    ce2sli["SLI / inside subnet<br/>internal listeners and origins"]
    ce2slo --> ce2 --> ce2sli
  end

  extOrigin["Public/shared app origin"]
  dualOrigin["Shared app origin"]
  intOrigin["Internal app origin"]

  extClient --> extDns --> publicLb --> extApp
  extClient --> extDns --> publicLb --> dualApp
  intClient --> intDns --> internalLb --> intApp
  intClient --> intDns --> internalLb --> dualApp

  extApp --> extPool
  dualApp --> dualPool
  intApp --> intPool

  extPool -. targets selected site in .-> vsite
  dualPool -. targets selected site in .-> vsite
  intPool -. targets selected site in .-> vsite

  vsite -. groups .-> ce1
  vsite -. groups .-> ce2

  ce1sli --> extOrigin
  ce2sli --> extOrigin
  ce1sli --> dualOrigin
  ce2sli --> dualOrigin
  ce1sli --> intOrigin
  ce2sli --> intOrigin
```

## External application sequence

1. An external client resolves the application's public DNS record.
2. The client connects either directly to the advertised CE outside VIP or through the optional Azure public load balancer.
3. The external application's XC HTTP load balancer receives the request on `SLO`.
4. That application's origin pool targets the shared XC Virtual Site.
5. The Virtual Site acts as a logical selector for the labeled Azure CE sites rather than a separate traffic-processing hop.
6. The CE forwards the request out its `SLI` inside interface to the application's private origin.

## Internal application sequence

1. An internal client resolves the application's internal DNS record.
2. The client connects either directly to the advertised CE inside VIP or through the optional Azure internal load balancer.
3. The internal application's XC HTTP load balancer receives the request on `SLI`.
4. That application's origin pool targets the shared XC Virtual Site.
5. The Virtual Site acts as a logical selector for the labeled Azure CE sites rather than a separate traffic-processing hop.
6. The CE forwards the request to the application's private origin on the inside network.

## Notes

- This diagram represents request traffic, not Terraform resource creation order.
- The repository does not deploy the application workloads; it only points each application to a private backend defined in `applications`.
- The XC Virtual Site is a logical grouping of CE sites selected by label. It is referenced by origin pools and HTTP load balancers, but it is not a separate packet-processing box.
- Management connectivity over the Secure Mesh public IP is intentionally omitted here because it is not in the application data path.
- Azure public and internal load balancers are optional resources in this Terraform. When enabled, the public LB creates one rule per external application port and the internal LB creates one rule per internal application port.
- Backend CE IPs are auto-discovered from Azure NICs by subnet membership when possible. If your deployment uses nonstandard addressing or multiple matching NICs, set the explicit backend IP override lists in `ce_sites`.
