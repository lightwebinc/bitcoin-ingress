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

# IPv4 anycast (optional)
anycast_prefix: "192.0.2.0/24"    # shared prefix announced by all nodes
anycast_vip: "192.0.2.1"          # loopback VIP configured on each node

# IPv6 anycast (optional)
anycast_prefix6: "2001:db8::/48"  # shared IPv6 prefix announced by all nodes
anycast_vip6: "2001:db8::1"       # IPv6 loopback VIP configured on each node

bgp_local_as: 65001               # ASN of this node
bgp_peer_as: 65000                # upstream provider ASN
bgp_peer_ip: "203.0.113.254"      # upstream IPv4 BGP peer (omit for IPv6-only)
bgp_peer_ip6: "2001:db8:feed::1" # upstream IPv6 BGP peer
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
         anycast_prefix:  192.0.2.0/24   (IPv4)
         anycast_prefix6: 2001:db8::/48  (IPv6)

node-A (AS 65001) ──eBGP(v4+v6)──► provider (AS 65000) ──► BGP table ──► senders
node-B (AS 65001) ──eBGP(v4+v6)──►                          (nearest wins)
node-C (AS 65001) ──eBGP(v4+v6)──►
```

Ingress is **dual-stack** — each node accepts BSV frames on both IPv4 and IPv6. The egress fabric
is **IPv6-only**, using ip6gre tunnels to the multicast switching layer.

---

## BIRD2

Installed on both Ubuntu 24.04 (`apt install bird2`) and FreeBSD 14 (`pkg install bird2`).

The `bgp` role writes `/etc/bird/bird.conf` from a Jinja2 template:

```bird
router id {{ bgp_router_id }};

protocol device {}
protocol direct { ipv4; ipv6; }
protocol kernel {
  ipv4 { export all; };
  ipv6 { export all; };
}

# Separate static protocols per address family
protocol static anycast4 {
  ipv4;
  route {{ anycast_prefix }} blackhole;   # set when anycast_prefix is non-empty
}

protocol static anycast6 {
  ipv6;
  route {{ anycast_prefix6 }} blackhole;  # set when anycast_prefix6 is non-empty
}

# Separate BGP sessions per peer address family
protocol bgp upstream4 {
  local as {{ bgp_local_as }};
  neighbor {{ bgp_peer_ip }} as {{ bgp_peer_as }};  # only when bgp_peer_ip set
  ...
  ipv4 { import none; export filter { if proto = "anycast4" then accept; reject; }; };
}

protocol bgp upstream6 {
  local as {{ bgp_local_as }};
  neighbor {{ bgp_peer_ip6 }} as {{ bgp_peer_as }}; # only when bgp_peer_ip6 set
  ...
  ipv6 { import none; export filter { if proto = "anycast6" then accept; reject; }; };
}
```

### Service check integration (BIRD2)

The `bgp` role installs a health-check script that disables both BGP sessions if the proxy
metrics endpoint (`/healthz`) returns non-200, triggering withdrawal of both v4 and v6 prefixes:

```bash
# /usr/local/bin/bsp-bgp-check.sh
#!/bin/sh
if curl -sf http://127.0.0.1:9100/healthz > /dev/null 2>&1; then
  birdc 'show protocols' > /dev/null 2>&1 || true
else
  birdc 'disable protocol upstream4' > /dev/null 2>&1 || true
  birdc 'disable protocol upstream6' > /dev/null 2>&1 || true
fi
```

Run every 10 seconds via a systemd timer (Ubuntu) or periodic cron (FreeBSD).

---

## FRRouting (FRR)

Installed on Ubuntu 24.04 (`apt install frr`) and FreeBSD 14 (`pkg install frr`).

Config paths differ by OS:

| OS           | Config directory      | Daemon selection                                              |
|--------------|-----------------------|---------------------------------------------------------------|
| Ubuntu 24.04 | `/etc/frr/`           | `/etc/frr/daemons` file                                       |
| FreeBSD 14   | `/usr/local/etc/frr/` | `frr_enable`, `zebra_enable`, `bgpd_enable` in `/etc/rc.conf` |

The `bgp` role writes `frr.conf` to the appropriate path and handles daemon selection per OS.

Example `frr.conf` (dual-stack):

```frr
frr defaults traditional
log syslog informational
!
router bgp {{ bgp_local_as }}
 bgp router-id {{ bgp_router_id }}
 neighbor {{ bgp_peer_ip }} remote-as {{ bgp_peer_as }}   ! IPv4 peer (if set)
 neighbor {{ bgp_peer_ip6 }} remote-as {{ bgp_peer_as }}  ! IPv6 peer (if set)
 !
 address-family ipv4 unicast
  network {{ anycast_prefix }}
  neighbor {{ bgp_peer_ip }} route-map EXPORT4 out
  neighbor {{ bgp_peer_ip }} route-map DENY in
 exit-address-family
 !
 address-family ipv6 unicast
  network {{ anycast_prefix6 }}
  neighbor {{ bgp_peer_ip6 }} route-map EXPORT6 out
  neighbor {{ bgp_peer_ip6 }} route-map DENY in
 exit-address-family
!
ip prefix-list ANYCAST4 seq 10 permit {{ anycast_prefix }}
ipv6 prefix-list ANYCAST6 seq 10 permit {{ anycast_prefix6 }}
route-map EXPORT4 permit 10
 match ip address prefix-list ANYCAST4
route-map EXPORT6 permit 10
 match ipv6 address prefix-list ANYCAST6
route-map DENY deny 10
!
```

Linux `/etc/frr/daemons`:

```text
bgpd=yes
zebra=yes
```

FreeBSD `/etc/rc.conf` entries (set by Ansible):

```text
frr_enable="YES"
zebra_enable="YES"
bgpd_enable="YES"
```

### Service check integration (FRR)

```bash
# /usr/local/bin/bsp-bgp-check.sh
#!/bin/sh
if curl -sf http://127.0.0.1:9100/healthz > /dev/null 2>&1; then
  vtysh -c 'show bgp summary' > /dev/null 2>&1 || true
else
  vtysh -c 'clear ip bgp {{ bgp_peer_ip }} soft out' > /dev/null 2>&1 || true    # IPv4 peer
  vtysh -c 'clear bgp ipv6 {{ bgp_peer_ip6 }} soft out' > /dev/null 2>&1 || true # IPv6 peer
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
        - "{{ anycast_vip }}/32"    # IPv4 VIP (if anycast_vip set)
        - "{{ anycast_vip6 }}/128"  # IPv6 VIP (if anycast_vip6 set)
```

### FreeBSD

```text
ifconfig_lo0_alias0="inet {{ anycast_vip }} netmask 255.255.255.255"  # IPv4 VIP
ifconfig_lo0_alias1="inet6 {{ anycast_vip6 }} prefixlen 128"          # IPv6 VIP
```

---

## Choosing a daemon

| Feature                    | BIRD2              | FRR                    |
|----------------------------|--------------------|------------------------|
| Ubuntu 24.04               | Yes                | Yes                    |
| FreeBSD 14                 | Yes                | Yes                    |
| Dual-stack (IPv4 + IPv6)   | Yes                | Yes                    |
| BFD support                | Yes                | Yes                    |
| Filter language            | BIRD filter lang   | Cisco-like CLI (vtysh) |
| PIM/PIM6 support           | No                 | Yes                    |
| MLD support                | No                 | Yes                    |

Both daemons support most features on both OSes. Choose based on operational preference:

- `bird2` — simpler config for this use case, BIRD filter language, no PIM/PIM6/MLD support, must be provided by other means if necessary. Not necessary if host is not routing multicast.
- `frr` — Cisco-like CLI via `vtysh`, familiar for network engineers
