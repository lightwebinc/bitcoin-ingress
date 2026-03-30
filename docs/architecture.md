# Architecture

## Overview

`bitcoin-ingress` deploys and configures `bitcoin-shard-proxy` nodes that form the ingress tier of a
Bitcoin SV multicast distribution fabric. Each node:

1. Receives raw BRC-12 UDP transaction frames from BSV senders on the public internet.
2. Derives an IPv6 multicast group address from the transaction ID shard key.
3. Retransmits the datagram to the derived group over one or more egress interfaces connected to the
   multicast fabric.

Because the proxy is fully stateless and deterministic (same txid always maps to the same group), any
number of ingress nodes can run simultaneously without coordination. Nodes are horizontally scalable
and individually replaceable.

## Network tiers

```text
                        ┌─────────────────────────────────────────┐
                        │  BSV Senders (wallets, apps, services)  │
                        └────────────┬────────────────────────────┘
                                     │  UDP unicast (BRC-12 frames)
                    ┌────────────────┼────────────────┐
                    │                │                │
              ┌─────▼──┐       ┌─────▼──┐       ┌─────▼──┐
              │ingress │       │ingress │       │ingress │   ← bitcoin-ingress nodes
              │node A  │       │node B  │       │node C  │     (this repo)
              └─────┬──┘       └─────┬──┘       └─────┬──┘
                    │  IPv6 UDP multicast  FF05::<shard>
                    └────────────────┼────────────────┘
                                     │  (GRE tunnel or ethernet)
                        ┌────────────▼────────────────────────────┐
                        │         Multicast fabric                │
                        │  (site-scoped, FF05::/16)               │
                        └────┬──────────┬──────────┬─────────────┘
                             │          │          │
                        ┌────▼──┐  ┌────▼──┐  ┌────▼──┐
                        │miners │  │exch-  │  │other  │   ← multicast subscribers
                        │       │  │anges  │  │SVPs   │     (join shard groups)
                        └───────┘  └───────┘  └───────┘
```

## Shard key and multicast group derivation

The proxy reads the top N bits of the transaction ID (configured via `shard_bits`) and maps them to
one of 2ᴺ IPv6 multicast group addresses. See the
[bitcoin-shard-proxy README](https://github.com/lightwebinc/bitcoin-shard-proxy) for the full
derivation formula and address format.

Subscribers join only the groups covering the shard ranges they care about. Increasing `shard_bits`
by 1 splits each existing group into two children — existing joins remain valid.

## AnyCast ingress (optional)

When `enable_bgp: true`, each ingress node announces a shared anycast IPv4 or IPv6 prefix via eBGP
to its upstream provider. All nodes announce the same prefix, so senders are routed to the
topologically nearest proxy by BGP best-path selection.

```text
Sender ──BGP anycast──► nearest ingress node ──multicast──► fabric
```

See [bgp-anycast.md](bgp-anycast.md) for configuration details.

## Egress interface options

| Mode          | When to use                                                          |
|---------------|----------------------------------------------------------------------|
| Plain ethernet| Ingress node is directly layer-2 adjacent to multicast fabric        |
| GRE tunnel    | Ingress node connects to fabric over IP (cloud VM, remote colocation)|

See [networking.md](networking.md) for interface configuration.

## Deployment topology examples

### Minimal (single node, ethernet egress)

```text
internet ──[eth0]── proxy node ──[eth1]── multicast fabric
```

### Multi-node AnyCast pool (GRE egress)

```text
internet ──anycast──► node-A ──GRE──┐
                    ► node-B ──GRE──┼──► fabric router ──► fabric
                    ► node-C ──GRE──┘
```

## OS support

| OS           | Service manager | Network config          |
|--------------|-----------------|-------------------------|
| Ubuntu 24.04 | systemd         | Netplan / ip commands   |
| FreeBSD 14   | rc.d            | rc.conf / ifconfig/gre  |
