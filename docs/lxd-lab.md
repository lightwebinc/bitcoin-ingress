# Deploying to an LXD lab

This guide covers deploying `bitcoin-shard-proxy` onto LXD VMs using the Ansible playbook in this repo. It is written for use with the [bitcoin-multicast-test](https://github.com/lightwebinc/bitcoin-multicast-test) lab topology but applies to any LXD-hosted Ubuntu 24.04 VM.

> **Version note:** `proxy_version` in `group_vars/all.yml` controls which git ref is checked out. The current default is `feat/v2-frame-sequencing`. The config template uses `UDP_LISTEN_PORT` and `TCP_LISTEN_PORT`; these are the correct environment variable names for that branch and for any later branch that includes TCP ingress support.

## Prerequisites

- LXD host with VMs running and reachable by SSH
- Ansible 2.15+ and collections installed (`pip install ansible && ansible-galaxy collection install community.general ansible.posix`)
- SSH key available on the control machine

## 1. Inject SSH key into target VMs

LXD VMs start without an `authorized_keys` file. Run from the LXD host:

```bash
PUBKEY=$(cat ~/.ssh/id_ed25519.pub)
lxc exec proxy -- bash -c "
  mkdir -p /home/ubuntu/.ssh && \
  echo '$PUBKEY' >> /home/ubuntu/.ssh/authorized_keys && \
  chmod 600 /home/ubuntu/.ssh/authorized_keys && \
  chown -R ubuntu:ubuntu /home/ubuntu/.ssh"
```

## 2. Create the inventory

Ubuntu 24.04 LXD VMs use predictable interface names (`enp5s0`, `enp6s0`), not `eth0`/`eth1`. Set `egress_iface` at the **host level** — not under `vars:` — because `group_vars/all.yml` takes higher precedence than inventory group vars in Ansible.

```yaml
# ansible/inventory/hosts.yml
all:
  children:
    ingress_nodes:
      vars:
        ansible_user: ubuntu
        ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
        egress_mode: ethernet
        shard_bits: 2
        mc_scope: site
        enable_bgp: false
      hosts:
        proxy:
          ansible_host: 10.10.10.20
          egress_iface: enp6s0   # host-level override required
```

## 3. Run the playbook

```bash
cd ansible/
ansible-playbook -i inventory/hosts.yml site.yml
```

The `common` role installs `acl` (required for Ansible `become` with system users on Ubuntu), Go, and build dependencies. The `bitcoin-shard-proxy` role clones, builds, and starts the service.

## 4. Enable bridge MLD querier (required)

MLD snooping alone is not sufficient — the bridge must also act as an MLD querier, otherwise it never queries ports for group membership and floods all multicast to all ports. Apply and persist the querier setting on the LXD host:

```bash
# Apply immediately
sudo sh -c 'echo 1 > /sys/devices/virtual/net/lxdbr1/bridge/multicast_querier'

# Persist across reboots via a systemd service
cat << 'EOF' | sudo tee /etc/systemd/system/lxd-bridge-mcast-querier.service
[Unit]
Description=Enable MLD querier on lxdbr1 for multicast snooping
After=sys-devices-virtual-net-lxdbr1.device
BindsTo=sys-devices-virtual-net-lxdbr1.device

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'echo 1 > /sys/devices/virtual/net/lxdbr1/bridge/multicast_querier'

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload && sudo systemctl enable --now lxd-bridge-mcast-querier.service
```

Verify: `cat /sys/devices/virtual/net/lxdbr1/bridge/multicast_querier` should print `1`.

## 5. Refresh bridge MDB on receivers

After deployment (and after the querier is active), receiver VMs need to re-send MLD membership reports to populate the bridge multicast database:

```bash
for vm in recv1 recv2 recv3; do
  lxc exec "$vm" -- systemctl restart mcast-join.service
done
bridge mdb show dev lxdbr1
```

## 6. Verify

```bash
# Service and health
lxc exec proxy -- systemctl status bitcoin-shard-proxy
lxc exec proxy -- curl -s http://localhost:9100/healthz
lxc exec proxy -- curl -s http://localhost:9100/readyz

# Send test frames from source VM over IPv6
lxc exec source -- send-test-frames -addr '[fd20::2]:9000' -shard-bits 2 -spread

# Check forwarded counter
lxc exec proxy -- curl -s http://localhost:9100/metrics | grep bsp_packets_forwarded_total

# Capture multicast on a receiver
lxc exec recv1 -- tcpdump -i enp6s0 -n 'ip6 and udp' -c 8
```

## Known issues and fixes

| Issue | Fix |
|-------|-----|
| `git clone` "dubious ownership" error | `community.general.git_config` sets `safe.directory` globally before `ansible.builtin.git` runs |
| `go build` VCS stamping error | `-buildvcs=false` added to build command |
| `ExecStartPre` shell redirection fails | Command wrapped in `/bin/sh -c '...'` in systemd unit template |
| `egress_iface` uses wrong default | Set at host level, not inventory `vars:` block |
| Ansible `become` fails without ACL support | `acl` package added to `common` role dependencies |
| Bridge MDB empty after deployment | Restart `mcast-join.service` on all receivers post-deploy |
| Multicast floods to all receivers despite MLD snooping | Enable `multicast_querier` on the bridge (see step 4) — snooping without a querier never suppresses flooding |

## Upgrade

```bash
ansible-playbook -i inventory/hosts.yml site.yml --tags proxy -e proxy_version=v1.2.0
```

After upgrading, restart `mcast-join.service` on receivers again to restore multicast delivery. Also verify the bridge querier is still active (`systemctl is-active lxd-bridge-mcast-querier.service`).
