# Ansible

## Requirements

- Ansible 2.15+
- Python 3.9+ on the control machine
- SSH access to target hosts with a user that has `sudo` / root privileges
- Supported target OS: Ubuntu 24.04 or FreeBSD 14

Install Ansible dependencies:

```bash
pip install ansible
ansible-galaxy collection install community.general ansible.posix
```

---

## Quick start

```bash
cd ansible/

# 1. Copy and edit the inventory
cp inventory/hosts.example.yml inventory/hosts.yml
$EDITOR inventory/hosts.yml

# 2. Review and override variables
$EDITOR group_vars/all.yml

# 3. Run the full playbook
ansible-playbook -i inventory/hosts.yml site.yml
```

---

## Inventory

`inventory/hosts.example.yml` shows the expected structure:

```yaml
all:
  children:
    ingress_nodes:
      hosts:
        node-01:
          ansible_host: 203.0.113.10
          ansible_user: ubuntu
          egress_iface: eth1
          bgp_peer_ip: 203.0.113.254
          bgp_router_id: 203.0.113.10
        node-02:
          ansible_host: 198.51.100.20
          ansible_user: ubuntu
          egress_iface: eth1
          bgp_peer_ip: 198.51.100.254
          bgp_router_id: 198.51.100.20
```

Host-level variables override `group_vars/all.yml`.

> **Important — `egress_iface` precedence**: `group_vars/all.yml` defines `egress_iface: eth1` as a default. Because Ansible gives `group_vars/all` higher precedence than inventory group `vars:` blocks, `egress_iface` **must be set per-host** (under `hosts: <name>:`) to take effect. Setting it only in the inventory `vars:` block will silently use the `group_vars/all.yml` default instead.

---

## Variables reference

All variables with defaults live in `group_vars/all.yml`.

### Proxy

| Variable          | Default     | Description                                      |
|-------------------|-------------|--------------------------------------------------|
| `proxy_repo`      | (GitHub URL)| git URL of bitcoin-shard-proxy source            |
| `proxy_version`   | `main`      | git ref (branch, tag, or SHA) to check out       |
| `proxy_install_dir`| `/opt/bitcoin-shard-proxy` | Clone and build destination       |
| `proxy_bin_dir`   | `/usr/local/bin` | Where to install the compiled binary         |
| `listen_addr`     | `[::]`      | Bind address for incoming frames                 |
| `listen_port`     | `9000`      | UDP ingress port                                 |
| `egress_port`     | `9001`      | UDP egress port for multicast groups             |
| `shard_bits`      | `8`         | Bit width of shard key (1–24)                    |
| `mc_scope`        | `site`      | Multicast scope: link / site / org / global      |
| `mc_base_addr`    | `""`        | Optional assigned IPv6 base address              |
| `num_workers`     | `0`         | Worker count (0 = runtime.NumCPU)                |
| `metrics_addr`    | `:9100`     | HTTP address for /metrics /healthz /readyz       |
| `otlp_endpoint`   | `""`        | OTLP gRPC endpoint (empty = disabled)            |
| `drain_timeout`   | `"0s"`      | Pre-drain delay before closing sockets on shutdown; set to `≥` LB health-check interval in production |

> **`TimeoutStopSec` relationship:** `systemd` sends `SIGKILL` after `TimeoutStopSec` if the service has not exited. Ensure `TimeoutStopSec > drain_timeout + 15s` (OTLP flush + drain buffer). The default service unit sets `TimeoutStopSec=30`, which is sufficient for `drain_timeout ≤ 15s`.

### Networking

| Variable          | Default      | Description                                     |
|-------------------|--------------|-------------------------------------------------|
| `egress_mode`     | `ethernet`   | `ethernet` or `gre`                             |
| `egress_iface`    | `eth1`       | Interface name(s) — list or comma string        |
| `gre_local_ip`    | `""`         | Local IP for GRE tunnel (gre mode only)         |
| `gre_remote_ip`   | `""`         | Remote GRE endpoint IP                          |
| `gre_iface`       | `gre0`       | GRE interface name                              |
| `gre_inner_ipv6`  | `""`         | IPv6 address/prefix for the GRE interface       |

### BGP / AnyCast

| Variable          | Default      | Description                                     |
|-------------------|--------------|-------------------------------------------------|
| `enable_bgp`      | `false`      | Enable eBGP AnyCast                             |
| `bgp_daemon`      | `bird2`      | `bird2` or `frr`                                |
| `anycast_prefix`  | `""`         | Shared prefix announced by all nodes            |
| `anycast_vip`     | `""`         | Loopback VIP from the anycast prefix            |
| `bgp_local_as`    | `65001`      | Local ASN                                       |
| `bgp_peer_as`     | `65000`      | Upstream provider ASN                           |
| `bgp_peer_ip`     | `""`         | Upstream BGP peer IP                            |
| `bgp_router_id`   | `""`         | BGP router ID (defaults to primary IPv4)        |
| `bgp_hold_time`   | `90`         | BGP hold time (seconds)                         |
| `bgp_keepalive`   | `30`         | BGP keepalive interval (seconds)                |
| `bgp_password`    | `""`         | Optional MD5 session password                   |

---

## Roles

| Role                    | Purpose                                                  |
|-------------------------|----------------------------------------------------------|
| `common`                | OS packages, Go toolchain install, build dependencies    |
| `bitcoin-shard-proxy`   | Clone, build, install binary, configure service unit     |
| `networking`            | Ethernet or GRE egress interface, IPv6 multicast routing |
| `bgp`                   | BIRD2 or FRR install, config template, health-check timer|

Roles are applied in the order listed by `site.yml`. The `bgp` role is skipped when `enable_bgp: false`.

---

## Tags

Run only specific roles using Ansible tags:

```bash
ansible-playbook -i inventory/hosts.yml site.yml --tags proxy
ansible-playbook -i inventory/hosts.yml site.yml --tags networking
ansible-playbook -i inventory/hosts.yml site.yml --tags bgp
ansible-playbook -i inventory/hosts.yml site.yml --tags common
```

---

## Upgrading the proxy

To pull a new version and rebuild:

```bash
ansible-playbook -i inventory/hosts.yml site.yml --tags proxy -e proxy_version=v1.2.0
```

The role will git-fetch, check out the new ref, run `make`, copy the binary, and restart the service.

---

## Idempotency

All roles are fully idempotent. Re-running the playbook is safe and will only apply changes when the
system state differs from the declared configuration.

---

## LXD / local lab deployment

See [docs/lxd-lab.md](lxd-lab.md) for a complete walkthrough covering SSH key injection, inventory setup, bridge MDB refresh, and known issues specific to LXD-hosted Ubuntu 24.04 VMs.
