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
| `bird2`               | pkg (if BGP)      | BIRD2 BGP daemon (FRR not in FreeBSD ports)|

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

- Ethernet egress: interface config appended to `/etc/rc.conf`.
- GRE tunnels: `cloned_interfaces` and `ifconfig_gre0` entries in `/etc/rc.conf`.
- AnyCast VIP: `ifconfig_lo0_alias0` in `/etc/rc.conf`.
- IPv6 is enabled via `ipv6_enable="YES"` and `gateway_enable="YES"` in `/etc/rc.conf`.

Apply interface changes without rebooting:

```bash
sudo service netif restart
sudo service routing restart
```

## BGP (BIRD2 only)

FRR is not available in the FreeBSD 14 ports tree. Use `bgp_daemon: bird2`.

```bash
sudo service bird enable
sudo service bird start
sudo birdc show protocols
sudo birdc show route
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
| `/etc/rc.conf`                                 | Interface and service settings  |

## Notes

- FreeBSD uses `gmake` instead of `make` for the Go build. The role passes `MAKE=gmake`.
- GRE interfaces are named `gre0`, `gre1`, etc. The kernel module `if_gre` is loaded automatically
  when `cloned_interfaces` is set.
- The Go binary is built as a static executable (`CGO_ENABLED=0`), so no shared library dependencies.
