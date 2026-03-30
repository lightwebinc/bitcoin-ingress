# eBGP AnyCast

## Overview

AnyCast allows all ingress proxy nodes to advertise a shared IP prefix. BSV senders resolve the
anycast address and are routed to the topologically nearest node by BGP best-path selection. This
provides:

- **Lowest-latency ingress** for senders without any application-level logic.
- **Automatic failover** — if a node goes down, its BGP session drops and senders are rerouted.
- **Horizontal scaling** — add more nodes, each announcing the same prefix.

AnyCast is **optional**. Set `enable_bgp: false` (the default) to run without it.

---

## Variables

```yaml
enable_bgp: true

bgp_daemon: bird2         # or: frr

anycast_prefix: "192.0.2.0/24"    # shared prefix announced by all nodes
anycast_vip: "192.0.2.1"          # loopback VIP configured on each node

bgp_local_as: 65001               # ASN of this node
bgp_peer_as: 65000                # upstream provider ASN
bgp_peer_ip: "203.0.113.254"      # upstream provider BGP peer IP
bgp_router_id: "{{ ansible_default_ipv4.address }}"

bgp_hold_time: 90
bgp_keepalive: 30

bgp_password: ""                  # optional MD5 session password
```

---

## How it works

Each node:

1. Configures a loopback VIP (`anycast_vip`) from the anycast prefix.
2. Runs a BGP daemon (BIRD2 or FRR) that opens an eBGP session to the upstream provider.
3. Announces `anycast_prefix` with `next-hop self`.
4. The service check (see below) withdraws the route if `bitcoin-shard-proxy` is unhealthy.

```text
         anycast_prefix: 192.0.2.0/24
         anycast_vip:    192.0.2.1

node-A (AS 65001) ──eBGP──► provider (AS 65000) ──► BGP table ──► senders
node-B (AS 65001) ──eBGP──►                          (nearest wins)
node-C (AS 65001) ──eBGP──►
```

---

## BIRD2

Installed on both Ubuntu 24.04 (`apt install bird2`) and FreeBSD 14 (`pkg install bird2`).

The `bgp` role writes `/etc/bird/bird.conf` from a Jinja2 template:

```
router id {{ bgp_router_id }};

protocol device {}
protocol direct { ipv4; ipv6; }
protocol kernel {
  ipv4 { export all; };
  ipv6 { export all; };
}

protocol static anycast_routes {
  ipv4;
  route {{ anycast_prefix }} blackhole;
}

protocol bgp upstream {
  local as {{ bgp_local_as }};
  neighbor {{ bgp_peer_ip }} as {{ bgp_peer_as }};
  hold time {{ bgp_hold_time }};
  keepalive time {{ bgp_keepalive }};
{% if bgp_password %}
  password "{{ bgp_password }}";
{% endif %}
  ipv4 {
    import none;
    export filter {
      if proto = "anycast_routes" then accept;
      reject;
    };
  };
}
```

### Service check integration (BIRD2)

The `bgp` role installs a health-check script that removes the static route from BIRD if the proxy
metrics endpoint (`/healthz`) returns non-200, triggering BGP withdrawal:

```bash
# /usr/local/bin/bsp-bgp-check.sh
#!/bin/sh
if curl -sf http://127.0.0.1:9100/healthz > /dev/null 2>&1; then
  birdc 'show route' > /dev/null   # no-op keep-alive
else
  birdc 'disable protocol bgp upstream'
fi
```

Run every 10 seconds via a systemd timer (Ubuntu) or periodic cron (FreeBSD).

---

## FRRouting (FRR)

Installed on Ubuntu 24.04 (`apt install frr`). FRR is not packaged for FreeBSD 14 in the default
ports tree; use BIRD2 on FreeBSD.

The `bgp` role writes `/etc/frr/frr.conf` and `/etc/frr/daemons`:

```
frr defaults traditional
log syslog informational
!
router bgp {{ bgp_local_as }}
 bgp router-id {{ bgp_router_id }}
 neighbor {{ bgp_peer_ip }} remote-as {{ bgp_peer_as }}
 neighbor {{ bgp_peer_ip }} timers {{ bgp_keepalive }} {{ bgp_hold_time }}
{% if bgp_password %}
 neighbor {{ bgp_peer_ip }} password {{ bgp_password }}
{% endif %}
 !
 address-family ipv4 unicast
  network {{ anycast_prefix }}
  neighbor {{ bgp_peer_ip }} route-map EXPORT out
  neighbor {{ bgp_peer_ip }} route-map DENY in
 exit-address-family
!
ip prefix-list ANYCAST seq 10 permit {{ anycast_prefix }}
route-map EXPORT permit 10
 match ip address prefix-list ANYCAST
route-map DENY deny 10
!
```

`/etc/frr/daemons`:

```
bgpd=yes
zebra=yes
```

### Service check integration (FRR)

```bash
# /usr/local/bin/bsp-bgp-check.sh
#!/bin/sh
if curl -sf http://127.0.0.1:9100/healthz > /dev/null 2>&1; then
  vtysh -c 'clear ip bgp soft' > /dev/null 2>&1 || true
else
  vtysh -c 'clear ip bgp {{ bgp_peer_ip }} soft out'
fi
```

---

## Loopback VIP

The role configures `anycast_vip` on the loopback interface so the OS responds to it:

### Ubuntu

```yaml
# /etc/netplan/62-bitcoin-ingress-vip.yaml
network:
  version: 2
  ethernets:
    lo:
      addresses:
        - "{{ anycast_vip }}/32"
```

### FreeBSD

```text
ifconfig_lo0_alias0="inet {{ anycast_vip }} netmask 255.255.255.255"
```

---

## Choosing a daemon

| Feature                    | BIRD2              | FRR                |
|----------------------------|--------------------|--------------------|
| Ubuntu 24.04               | Yes                | Yes                |
| FreeBSD 14                 | Yes                | No (not in ports)  |
| BFD support                | Yes (via bfd proto)| Yes                |
| Community / filter language| BIRD filter lang   | Cisco-like CLI     |

Set `bgp_daemon: bird2` (default) for cross-platform support. Use `bgp_daemon: frr` on Ubuntu-only
deployments if FRR's CLI is preferred.
