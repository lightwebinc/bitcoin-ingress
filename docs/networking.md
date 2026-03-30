# Networking

## Egress interface modes

`bitcoin-shard-proxy` sends IPv6 UDP multicast datagrams out of one or more named network interfaces.
The `networking` Ansible role configures the egress interface in one of two modes:

| Mode          | Variable                  | Description                                           |
|---------------|---------------------------|-------------------------------------------------------|
| Plain ethernet| `egress_mode: ethernet`   | Use an existing physical/VLAN interface as-is         |
| GRE tunnel    | `egress_mode: gre`        | Create a GRE tunnel to a remote fabric endpoint       |

Set `egress_mode` in `ansible/group_vars/all.yml` or per-host in the inventory.

---

## Plain ethernet

The simplest configuration. The proxy node has a physical or logical interface directly on (or routed
to) the multicast fabric L2 segment. No additional setup is required beyond ensuring IPv6 is enabled
on the interface and that multicast routing/MLD snooping is configured on the fabric switches.

```yaml
egress_mode: ethernet
egress_iface: eth1        # interface name on target host
```

### Ubuntu 24.04 — Netplan snippet

The `networking` role writes `/etc/netplan/60-bitcoin-ingress.yaml`:

```yaml
network:
  version: 2
  ethernets:
    eth1:
      dhcp4: false
      dhcp6: false
      addresses:
        - "2001:db8:1::1/64"
```

### FreeBSD 14 — rc.conf snippet

The role appends to `/etc/rc.conf`:

```text
ifconfig_vtnet1_ipv6="inet6 2001:db8:1::1 prefixlen 64"
```

---

## GRE tunnel

Use GRE when the ingress node connects to the multicast fabric over IP (e.g., a cloud VM reaching a
colocation fabric router). The role creates a GRE interface, assigns an IPv6 address to it, and
configures the routing table so multicast traffic uses the tunnel.

```yaml
egress_mode: gre
gre_local_ip: "203.0.113.10"      # public IP of this node
gre_remote_ip: "198.51.100.1"     # fabric router GRE endpoint
gre_iface: gre0                   # tunnel interface name
gre_inner_ipv6: "2001:db8:2::2/64"
```

### Ubuntu 24.04

The role creates `/etc/netplan/61-bitcoin-ingress-gre.yaml` and a systemd-networkd `.netdev`:

```ini
# /etc/systemd/network/gre0.netdev
[NetDev]
Name=gre0
Kind=gre

[Tunnel]
Local=203.0.113.10
Remote=198.51.100.1
```

```yaml
# /etc/netplan/61-bitcoin-ingress-gre.yaml
network:
  version: 2
  tunnels:
    gre0:
      mode: gre
      local: "203.0.113.10"
      remote: "198.51.100.1"
      addresses:
        - "2001:db8:2::2/64"
```

### FreeBSD 14

The role appends to `/etc/rc.conf`:

```text
cloned_interfaces="gre0"
ifconfig_gre0="tunnel 203.0.113.10 198.51.100.1"
ifconfig_gre0_ipv6="inet6 2001:db8:2::2 prefixlen 64"
```

---

## IPv6 multicast routing

On both OSes, the role ensures:

- IPv6 forwarding is enabled.
- The FF00::/8 multicast route is present on the egress interface.

### Ubuntu

```bash
sysctl -w net.ipv6.conf.all.forwarding=1
ip -6 route add ff00::/8 dev <egress_iface> table local
```

Persisted via `/etc/sysctl.d/60-bitcoin-ingress.conf` and a systemd `ExecStartPre` in the service unit.

### FreeBSD

```text
# /etc/rc.conf
ipv6_enable="YES"
gateway_enable="YES"
```

---

## Multiple egress interfaces

`bitcoin-shard-proxy` supports comma-separated `-iface` values and fans out each datagram to all
listed interfaces. To use multiple egress interfaces, set `egress_iface` as a list:

```yaml
egress_iface:
  - eth1
  - gre0
```

The role joins the list into a comma-separated string and passes it to the `-iface` flag.

---

## Ingress interface

The ingress (sender-facing) interface is where `bitcoin-shard-proxy` listens for BRC-12 UDP frames.
This is typically the default route interface and requires no special configuration beyond reachability
from senders.

```yaml
listen_addr: "[::]"     # bind all interfaces
listen_port: 9000
```

If eBGP AnyCast is enabled, the ingress interface IP (or anycast VIP) is announced via BGP.
See [bgp-anycast.md](bgp-anycast.md).
