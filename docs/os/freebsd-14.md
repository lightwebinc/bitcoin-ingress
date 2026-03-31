# FreeBSD 14

## System requirements

- FreeBSD 14.0-RELEASE or later
- IPv6 enabled on the egress interface
- Internet access for pkg installation and cloning `bitcoin-shard-proxy`
- `sudo` or root access for the Ansible user

## What the Ansible roles install

| Package / component   | Source            | Notes                                      |
|-----------------------|-------------------|--------------------------------------------|
| `gmake`               | pkg               | GNU make for Go build                      |
| `git`                 | pkg               | clone bitcoin-shard-proxy                  |
| `curl`                | pkg               | health-check script                        |
| `bash`                | pkg               | required by some build scripts             |
| Go toolchain          | go.dev tarball    | version set by `go_version` variable       |
| `bitcoin-shard-proxy` | built from source | binary in `/usr/local/bin/`                |
| `bird2`               | pkg (if BGP)      | BIRD2 BGP daemon                           |
| `frr`                 | pkg (if BGP)      | FRRouting BGP daemon (alternative to BIRD2)|

## Service management

The proxy runs as an **rc.d service** (`bitcoin_shard_proxy`). The rc.d script is templated from
`roles/bitcoin-shard-proxy/templates/bitcoin_shard_proxy.rc.j2`.

```bash
# Enable and start
sudo service bitcoin_shard_proxy enable
sudo service bitcoin_shard_proxy start

# Status / restart
sudo service bitcoin_shard_proxy status
sudo service bitcoin_shard_proxy restart

# Logs (via syslog)
sudo tail -f /var/log/messages | grep bitcoin_shard_proxy
```

## Networking

- Ingress interface: dual-stack (DHCP + SLAAC), set via `ifconfig_<iface>` and `ifconfig_<iface>_ipv6` in `/etc/rc.conf`.
- GRE tunnels: IPv6-only (`gif0`), using `cloned_interfaces="gif0"` and `ifconfig_gif0="tunnel <local_ipv6> <remote_ipv6>"` in `/etc/rc.conf`.
- AnyCast VIPs: `ifconfig_lo0_alias0` (IPv4) and `ifconfig_lo0_alias1` (IPv6) in `/etc/rc.conf`.
- IPv4/IPv6 forwarding enabled via `gateway_enable="YES"` and `ipv6_gateway_enable="YES"`.

Apply interface changes without rebooting:

```bash
sudo service netif restart
sudo service routing restart
```

## BGP (BIRD2 or FRR)

Both BIRD2 and FRR are available via `pkg` on FreeBSD 14. The `bgp_daemon` variable selects which
one is installed and configured by the `bgp` Ansible role.

### BIRD2

```bash
sudo service bird enable
sudo service bird start
sudo birdc show protocols
sudo birdc show route
```

### FRR

FRR on FreeBSD uses `/usr/local/etc/frr/frr.conf` and rc.conf daemon flags instead of the
`/etc/frr/daemons` file used on Linux.

```bash
sudo service frr enable
sudo service frr start
sudo vtysh -c 'show bgp summary'
sudo vtysh -c 'show bgp ipv6 summary'
```

## Firewall

The Ansible `common` role does not manage `pf` rules — add rules for your site policy. Ports that
must be reachable:

| Port | Protocol | Direction | Purpose                                |
|------|----------|-----------|----------------------------------------|
| 9000 | UDP      | inbound   | bitcoin-shard-proxy ingress            |
| 179  | TCP      | in+out    | BGP (if `enable_bgp: true`)            |
| 9100 | TCP      | inbound   | Prometheus metrics / health endpoints  |

## File locations

| Path                                           | Content                         |
|------------------------------------------------|---------------------------------|
| `/usr/local/bin/bitcoin-shard-proxy`           | Compiled binary                 |
| `/usr/local/etc/bitcoin-shard-proxy.conf`      | Environment variable config     |
| `/usr/local/etc/rc.d/bitcoin_shard_proxy`      | rc.d service script             |
| `/usr/local/bitcoin-shard-proxy/`              | Source clone and build directory|
| `/usr/local/etc/bird/bird.conf`                | BIRD2 config (if enabled)       |
| `/usr/local/etc/frr/frr.conf`                  | FRR config (if enabled)         |
| `/etc/rc.conf`                                 | Interface and service settings  |

## Notes

- FreeBSD uses `gmake` instead of `make` for the Go build. The role passes `MAKE=gmake`.
- GRE tunnels use `gif0` (IPv6-in-IPv6, `if_gif` kernel module), not `gre0`. The fabric is IPv6-only.
- FRR config is in `/usr/local/etc/frr/` on FreeBSD; daemon selection uses rc.conf vars (`frr_enable`, `zebra_enable`, `bgpd_enable`) instead of the Linux `/etc/frr/daemons` file.
- The Go binary is built as a static executable (`CGO_ENABLED=0`), so no shared library dependencies.
