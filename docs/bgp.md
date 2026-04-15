# eBGP

## Overview

This feature allows all ingress proxy nodes to advertise a shared IP prefix. BSV senders resolve the
shared address and are routed to the topologically nearest node by BGP best-path selection. This
provides:

- **Lowest-latency ingress** for senders without any application-level logic.
- **Automatic failover** — if a node goes down, its BGP session drops and senders are rerouted.
- **Horizontal scaling** — add more nodes, each announcing the same prefix.

BGP is **optional**. Set `enable_bgp: false` (the default) to run without it.

---

## Variables

```yaml
enable_bgp: true

bgp_daemon: bird2         # or: frr

# IPv4 BGP prefix (optional)
bgp_prefix: "192.0.2.0/24"    # shared prefix announced by all nodes
bgp_vip: "192.0.2.1"          # loopback VIP configured on each node

# IPv6 BGP prefix (optional)
bgp_prefix6: "2001:db8::/48"  # shared IPv6 prefix announced by all nodes
bgp_vip6: "2001:db8::1"       # IPv6 loopback VIP configured on each node

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

1. Configures a loopback VIP (`bgp_vip`) from `bgp_prefix`.
2. Runs a BGP daemon (BIRD2 or FRR) that opens an eBGP session to the upstream provider.
3. Announces `bgp_prefix` with `next-hop self`.
4. The service check (see below) withdraws the route if `bitcoin-shard-proxy` is unhealthy.

```text
         bgp_prefix:  192.0.2.0/24   (IPv4)
         bgp_prefix6: 2001:db8::/48  (IPv6)

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
protocol static bgp4 {
  ipv4;
  route {{ bgp_prefix }} blackhole;   # set when bgp_prefix is non-empty
}

protocol static bgp6 {
  ipv6;
  route {{ bgp_prefix6 }} blackhole;  # set when bgp_prefix6 is non-empty
}

# Prefix-set filters (conditionally defined when the prefix var is set)
define BGP4_PFXS = [ {{ bgp_prefix }} ];
filter export_bgp4 { if net ~ BGP4_PFXS then accept; reject; }

define BGP6_PFXS = [ {{ bgp_prefix6 }} ];
filter export_bgp6 { if net ~ BGP6_PFXS then accept; reject; }

filter accept_none { reject; }

# Separate BGP sessions per peer address family
protocol bgp upstream4 {
  local as {{ bgp_local_as }};
  neighbor {{ bgp_peer_ip }} as {{ bgp_peer_as }};  # only when bgp_peer_ip set
  ...
  ipv4 { import filter accept_none; export filter export_bgp4; };
}

protocol bgp upstream6 {
  local as {{ bgp_local_as }};
  neighbor {{ bgp_peer_ip6 }} as {{ bgp_peer_as }}; # only when bgp_peer_ip6 set
  ...
  ipv6 { import filter accept_none; export filter export_bgp6; };
}
```

### Service check integration (BIRD2)

The `bgp` role installs a health-check script (`/usr/local/bin/bsp-bgp-check.sh`) that:

- **Healthy** — re-enables both BGP sessions (no-op if they were already up).
- **Unhealthy** — disables both sessions, triggering immediate prefix withdrawal.

```bash
# /usr/local/bin/bsp-bgp-check.sh (BIRD2 path)
if curl -sf http://127.0.0.1:9100/healthz > /dev/null 2>&1; then
  birdc 'enable protocol upstream4' > /dev/null 2>&1 || true
  birdc 'enable protocol upstream6' > /dev/null 2>&1 || true
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
  network {{ bgp_prefix }}
  neighbor {{ bgp_peer_ip }} route-map EXPORT4 out
  neighbor {{ bgp_peer_ip }} route-map DENY in
 exit-address-family
 !
 address-family ipv6 unicast
  network {{ bgp_prefix6 }}
  neighbor {{ bgp_peer_ip6 }} route-map EXPORT6 out
  neighbor {{ bgp_peer_ip6 }} route-map DENY in
 exit-address-family
!
ip prefix-list BGP4 seq 10 permit {{ bgp_prefix }}
ipv6 prefix-list BGP6 seq 10 permit {{ bgp_prefix6 }}
route-map EXPORT4 permit 10
 match ip address prefix-list BGP4
route-map EXPORT6 permit 10
 match ipv6 address prefix-list BGP6
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
# /usr/local/bin/bsp-bgp-check.sh (FRR path)
if curl -sf http://127.0.0.1:9100/healthz > /dev/null 2>&1; then
  # Re-enable sessions shut down by a previous health failure
  vtysh -c "configure terminal" -c "router bgp $AS" -c "no neighbor $PEER_IP shutdown"
  vtysh -c "configure terminal" -c "router bgp $AS" -c "no neighbor $PEER_IP6 shutdown"
else
  # Shut down sessions — peer withdraws routes it learned from us
  vtysh -c "configure terminal" -c "router bgp $AS" -c "neighbor $PEER_IP shutdown"
  vtysh -c "configure terminal" -c "router bgp $AS" -c "neighbor $PEER_IP6 shutdown"
fi
```

---

## Service Ordering

When `enable_bgp: true`, the `bitcoin-shard-proxy.service` unit gains two extra directives:

```ini
[Unit]
# Ensures the BGP daemon stops *after* the proxy — so the daemon can process
# the withdrawal before it exits.
Before=bird.service   # or Before=frr.service when bgp_daemon == frr

[Service]
# Called synchronously before the process is killed.
# Withdraws all BGP sessions immediately so route propagation starts
# as early as possible during a graceful stop.
ExecStop=/usr/local/bin/bsp-bgp-withdraw.sh
```

The `bsp-bgp-withdraw.sh` script is deployed by the `bgp` role to `/usr/local/bin/` alongside
the health-check script.

---

## iBGP

The `bgp-ibgp` role (`roles/bgp-ibgp/`) configures iBGP sessions on **upstream peer nodes**
(e.g. core routers) so they learn the anycast prefix from the ingress proxy nodes. It is run
by the separate `ansible/bgp-ibgp.yml` playbook against the `bgp_ibgp_nodes` inventory group.

### Variables

```yaml
# Per-host list of iBGP peers (same AS as bgp_local_as)
bgp_ibgp_peers:
  # At least one of peer_ip or peer_ip6 is required per entry.
  # Include both for dual-stack peers.
  - { peer_ip: "10.0.1.1", description: "proxy-node-01" }          # v4 only
  - { peer_ip6: "fd00::1", description: "proxy-node-02" }          # v6 only
  - { peer_ip: "10.0.1.3", peer_ip6: "fd00::3", description: "proxy-node-03" } # dual-stack
```

The `bgp_local_as`, `bgp_prefix`, `bgp_prefix6`, `bgp_hold_time`, `bgp_keepalive`,
and `bgp_password` variables are shared with the existing `bgp` role.

### BIRD2 iBGP session pattern

For each peer entry the template generates one or two `protocol bgp` blocks:

```bird
# Peer with peer_ip set
protocol bgp ibgp_0_v4 {
  local as 65001;
  neighbor 10.0.1.1 as 65001;   # same AS = iBGP
  ...
  ipv4 { next hop self; import filter accept_none; export filter export_bgp4; };
}

# Peer with peer_ip6 set
protocol bgp ibgp_0_v6 {
  local as 65001;
  neighbor fd00::3 as 65001;
  ...
  ipv6 { next hop self; import filter accept_none; export filter export_bgp6; };
}
```

### FRR iBGP session pattern

```frr
router bgp 65001
 neighbor 10.0.1.1 remote-as 65001
 neighbor 10.0.1.1 update-source 192.0.2.1  ! if bgp_vip set
 neighbor fd00::3  remote-as 65001
 neighbor fd00::3  update-source 2001:db8::1 ! if bgp_vip6 set
 !
 address-family ipv4 unicast
  network 192.0.2.0/24
  neighbor 10.0.1.1 next-hop-self
  neighbor 10.0.1.1 route-map EXPORT4 out
  neighbor 10.0.1.1 route-map DENY in
 exit-address-family
 !
 address-family ipv6 unicast
  network 2001:db8::/48
  neighbor fd00::3  next-hop-self
  neighbor fd00::3  route-map EXPORT6 out
  neighbor fd00::3  route-map DENY in
 exit-address-family
```

---

## Egress BGP

BGP is **not used on the egress side**. Egress delivers IPv6 multicast frames to receivers over
physical interfaces or ip6gre tunnels:

- **MLD** (Multicast Listener Discovery) handles group membership on each egress interface.
- **PIM** handles multicast tree building across L3 boundaries if needed.
- ip6gre tunnel endpoints require only unicast reachability (static route / directly connected),
  which is already handled by the `networking` role.
- Egress is one-way; receivers do not send unicast traffic back to the proxy.

If a future use case requires advertising a unicast prefix downstream over GRE6, that can be
added as a separate `bgp-ebgp` role at that time.

---

## Playbooks

| Playbook | Target group | Role | Purpose |
|---|---|---|---|
| `ansible/site.yml` | `ingress_nodes` | `bgp` (conditional) | eBGP on ingress proxy nodes |
| `ansible/bgp-ibgp.yml` | `bgp_ibgp_nodes` | `bgp-ibgp` | iBGP on upstream peer nodes |

Run independently:

```bash
# Deploy eBGP on ingress nodes
ansible-playbook -i inventory/hosts.yml site.yml

# Deploy iBGP on upstream peer nodes
ansible-playbook -i inventory/hosts.yml bgp-ibgp.yml
```

---

## Loopback VIP

The role configures `bgp_vip` on the loopback interface so the OS responds to it:

### Ubuntu

```yaml
# /etc/netplan/62-bitcoin-ingress-vip.yaml
network:
  version: 2
  ethernets:
    lo:
      addresses:
        - "{{ bgp_vip }}/32"    # IPv4 VIP (if bgp_vip set)
        - "{{ bgp_vip6 }}/128"  # IPv6 VIP (if bgp_vip6 set)
```

### FreeBSD

```text
ifconfig_lo0_alias0="inet {{ bgp_vip }} netmask 255.255.255.255"  # IPv4 VIP
ifconfig_lo0_alias1="inet6 {{ bgp_vip6 }} prefixlen 128"          # IPv6 VIP
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
