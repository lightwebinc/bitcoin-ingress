# Architecture

## Overview

`bitcoin-ingress` deploys and configures `bitcoin-shard-proxy` nodes that form the ingress tier of a
Bitcoin SV multicast distribution fabric. Each node:

1. Receives raw BRC-12 transaction frames from BSV senders on the public internet (UDP by default; TCP ingress is optional for reliable delivery).
2. Derives an IPv6 multicast group address from the transaction ID shard key.
3. Retransmits the datagram to the derived group over one or more egress interfaces connected to the
   multicast fabric.

Because the proxy is fully stateless and deterministic (same txid always maps to the same group), any
number of ingress nodes can run simultaneously without coordination. Nodes are horizontally scalable
and individually replaceable.

## Network tiers

```text
                        ┌─────────────────────────────────────────┐
                        │  BSV Senders (miners, services)         │
                        └────────────┬────────────────────────────┘
                                     │  UDP / TCP (BRC-12 / V2 frames)
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
                        └────┬──────────┬──────────┬──────────────┘
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

## Subtree-based sharding

In addition to using a fixed number of shards, we can further divide traffic flows into subtree-flows using subtree identifiers set by miners and transaction processors. This allows for more flexible sharding and can be used to shard by transaction type, specialty, or other criteria. The details of this mechanism are still being worked out, particularly the deterministic mapping of the 32 byte subtree identifier to multicast group address scheme. The V2 frame format includes a field for the subtree ID already.

## Sequence numbering

The V2 frame format includes a sequence number field that can be used to track the order of transactions within a shard. This can be used by receivers to detect missing transactions and request retransmission. It is still yet to be determined if this field should be set only by the transmission originator (i.e. miners, transaction processors, infrastructure services, exchanges, etc.) or if it should be set by the ingress node in the case that an originator leaves this field blank, or uses the standard BRC-12 transaction format without these fields.

The sequence numbering needs to be monotonic. This introduces potential complexity in coordination among proxy workers on a single system, and also between proxy systems.

## BGP ingress (optional)

When `enable_bgp: true`, each ingress node announces IPv4 or IPv6 prefixes via eBGP
to its upstream provider. All nodes can announce the same prefixes, so senders are routed to the
topologically nearest proxy by BGP best-path selection.

```text
Sender ──BGP──► nearest ingress node ──multicast──► fabric
```

See [bgp.md](bgp.md) for configuration details.

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

### Multi-node BGP pool (GRE egress)

```text
internet ──BGP──► node-A ──GRE──┐
                    ► node-B ──GRE──┼──► fabric router ──► fabric
                    ► node-C ──GRE──┘
```

## OS support

| OS           | Service manager | Network config          |
|--------------|-----------------|-------------------------|
| Ubuntu 24.04 | systemd         | Netplan / ip commands   |
| FreeBSD 14   | rc.d            | rc.conf / ifconfig/gre  |
