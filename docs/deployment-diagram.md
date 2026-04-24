# Deployment diagram

This diagram shows the objects created by this Terraform stack and the interfaces used by each Azure Customer Edge (CE) site.

```mermaid
flowchart LR
  clients["Clients"]
  dns["External DNS<br/>app_domain -> XC HTTP LB"]

  subgraph xc["F5 Distributed Cloud tenant"]
    credential["Pre-existing XC Azure credential"]
    labels["Known label + cloud site labels"]
    vsite["XC Virtual Site"]
    originPool["XC Origin Pool<br/>inside network"]
    httpLb["XC HTTP Load Balancer<br/>domains = [app_domain]<br/>advertise_network = SITE_NETWORK_OUTSIDE"]
  end

  subgraph site1["Azure CE Site 1"]
    ce1["Single-node Azure CE"]
    ce1slo["SLO / outside subnet<br/>client-facing interface"]
    ce1sli["SLI / inside subnet<br/>origin-facing interface"]
    ce1sm["Secure Mesh public IP<br/>control-plane connectivity"]
    ce1 --- ce1slo
    ce1 --- ce1sli
    ce1 --- ce1sm
  end

  subgraph site2["Azure CE Site 2"]
    ce2["Single-node Azure CE"]
    ce2slo["SLO / outside subnet<br/>client-facing interface"]
    ce2sli["SLI / inside subnet<br/>origin-facing interface"]
    ce2sm["Secure Mesh public IP<br/>control-plane connectivity"]
    ce2 --- ce2slo
    ce2 --- ce2sli
    ce2 --- ce2sm
  end

  origin["Private origin application<br/>private_ip or private_name : origin_port"]

  credential -. provisions .-> ce1
  credential -. provisions .-> ce2

  ce1 -. labeled .-> labels
  ce2 -. labeled .-> labels
  labels --> vsite

  clients --> dns --> httpLb
  httpLb --> originPool
  originPool --> vsite

  vsite --> ce1sli
  vsite --> ce2sli
  ce1sli --> origin
  ce2sli --> origin

  httpLb -. advertised on .-> ce1slo
  httpLb -. advertised on .-> ce2slo
  xc -. manages .-> ce1sm
  xc -. manages .-> ce2sm
```

## Interface roles

- **SLO / outside subnet**
  - client-facing side of the CE
  - used to advertise the HTTP load balancer on `SITE_NETWORK_OUTSIDE`
- **SLI / inside subnet**
  - backend-facing side of the CE
  - used by the origin pool to reach the private application
- **Secure Mesh public IP**
  - used for CE control-plane connectivity to F5 XC
  - this is management connectivity, not the private application path

## Notes

- The application itself is not deployed by this repository; the origin is an external private IP or private DNS name supplied through `origin_server_value`.
- DNS for `app_domain` is expected to be managed outside this stack because the load balancer sets `dns_volterra_managed = false`.
