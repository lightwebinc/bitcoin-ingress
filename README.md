# bitcoin-ingress

Automation tooling for deploying [bitcoin-shard-proxy](https://github.com/lightwebinc/bitcoin-shard-proxy) as
a horizontally-distributed, stateless Bitcoin ingress proxy fleet — packaged into OS installations, networked,
and run hands-off.

## Goals

- **Diversified data injection**: deploy ingress proxies across geographically distributed nodes so Bitcoin
  transaction data enters the multicast fabric from many independent points.
- **Multicast fabric integration**: connect ingress proxy pools to the IPv6 multicast network fabric serving
  Bitcoin miners, exchanges, and other service providers as tiered multicast group subscribers.
- **Stateless & deterministic**: because `bitcoin-shard-proxy` carries no state, proxies can be added,
  removed, or replaced at any time without coordination.
- **Horizontal scale**: shard-bit doubling splits multicast groups without invalidating existing subscriber
  joins — scale up by deploying more nodes, not by reconfiguring existing ones.

## Architecture overview

```text
Internet / BSV senders
        │  UDP (BRC-12 frames)
        ▼
┌──────────────────────┐
│  bitcoin-ingress     │  ← this repo manages deployment of these nodes
│  proxy node          │
│  (bitcoin-shard-proxy│
│   binary)            │
└──────┬───────────────┘
       │  IPv6 UDP multicast (FF05::<shard>)
       │  via ethernet or GRE tunnel egress
       ▼
┌──────────────────────────────────────────────┐
│  Multicast fabric                            │
│  (miners, exchanges, service providers)      │
│  — subscribe to shard groups of interest —   │
└──────────────────────────────────────────────┘
```

Optional eBGP AnyCast on the ingress interface advertises a shared anycast prefix from all proxy nodes,
allowing senders to reach the nearest proxy automatically.

See [docs/architecture.md](docs/architecture.md) for full topology detail.

## Supported platforms

| OS            | Automation  | Notes                                  |
|---------------|-------------|----------------------------------------|
| Ubuntu 24.04  | Ansible     | systemd service unit                   |
| FreeBSD 14    | Ansible     | rc.d service script                    |
| Any SSH host  | Terraform   | cloud-agnostic null_resource module    |
| AWS EC2       | Terraform   | VPC / SG / EC2 / optional EIP          |

## Quick start

1. **Ansible** — see [docs/ansible.md](docs/ansible.md)
2. **Terraform (generic)** — see [docs/terraform.md](docs/terraform.md)
3. **Networking (GRE / ethernet)** — see [docs/networking.md](docs/networking.md)
4. **eBGP AnyCast** — see [docs/bgp-anycast.md](docs/bgp-anycast.md)

## Repository layout

```text
ansible/          Ansible roles and playbooks
terraform/        Terraform modules and cloud examples
docs/             Per-topic documentation
.github/          CI lint workflows
```

## References

- [bitcoin-shard-proxy](https://github.com/lightwebinc/bitcoin-shard-proxy) — the proxy this repo deploys
- [Multicast within Multicast: AnyCast](https://singulargrit.substack.com/p/multicast-within-multicast-anycast)
- [Multicast as the Only Viable Architecture](https://singulargrit.substack.com/p/multicast-as-the-only-viable-architecture)

## License

Apache 2.0
