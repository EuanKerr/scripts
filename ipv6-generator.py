#!/usr/bin/env python3
"""
2024 Euan Kerr

A script to split an IPv6 /56 range into smaller /64 ranges.
Because docker doesn't support IPv6 PD yet, we need to split the /56 range into /64 subnets and assign one of them to the docker server.
Then we need to update the pfsense configuration to use the new docker server IP and subnet with static routes and aliases.whe
"""

import ipaddress
import sys
from typing import List, Dict


class InvalidIPv6Range(Exception):
    def __init__(self, message: str = "Invalid IPv6 range"):
        self.message = message
        super().__init__(self.message)


def print_steps(name: str, steps: List[str]) -> None:
    print(f"\n{name.upper()}:")
    for i, step in enumerate(steps, start=1):
        print(f"Step {i}: {step}")


def split_ipv6_range(ipv6_range: str) -> None:
    """
    Split an IPv6 /56 range into smaller /64 ranges.

    Args:
    ipv6_range (str): The IPv6 /56 range to split.

    Returns:
    None
    """
    # Create an IPv6 network object
    try:
        network = ipaddress.ip_network(ipv6_range)
        if network.prefixlen > 59:
            raise InvalidIPv6Range("Should be /59 IPv6 range or larger.")
    except ValueError:
        raise InvalidIPv6Range("Invalid IPv6 range")

    # Split the /56 range into /64 subnets
    subnets = list(network.subnets(new_prefix=64))

    # Assign the subnets
    subnets_dict: Dict[str, ipaddress.IPv6Network or ipaddress.IPv6Address] = {
        "lan_subnet": subnets[0],
        "lan_prefix_delegation_subnets": subnets[5:16],
        "docker_subnet": subnets[16],
        "docker_ip": ipaddress.IPv6Address(
            int(network.network_address) + 4919
        ),  # 4919 is the decimal representation of 1337
    }

    print(f"LAN subnet: {subnets_dict['lan_subnet']}")
    print(
        f"LAN PD range: {str(subnets_dict['lan_prefix_delegation_subnets'][0]).split('/')[0]} - {str(subnets_dict['lan_prefix_delegation_subnets'][-1]).split('/')[0]}"
    )
    print(f"Docker subnet: {subnets_dict['docker_subnet']}")
    print(f"Docker server: {subnets_dict['docker_ip']}")

    docker_steps: List[str] = [
        f"Replace IPv6 subnet in /opt/networks-compose.yml with {subnets_dict['docker_subnet']} and the gateway with {subnets_dict['docker_subnet'].network_address + 1}",
        "reboot or `docker compose up -d`",
    ]
    print_steps("docker", docker_steps)

    pfsense_steps: List[str] = [
        f"In pfsense Services>DHCPv6 Server>LAN replace the PD range with {str(subnets_dict['lan_prefix_delegation_subnets'][0]).split('/')[0]} to {str(subnets_dict['lan_prefix_delegation_subnets'][-1]).split('/')[0]}",
        f"In pfsense System>Routing>Gateways update docker_gw gateway with {subnets_dict['docker_subnet'].network_address}",
        f"In pfsense System>Routing>Static Routes update destination network for {subnets_dict['docker_subnet']} via {subnets_dict['docker_ip']}",
        f"In pfsense Firewall>Aliases>Docker update the alias with {subnets_dict['docker_ip']}",
        f"In pfsense Services>DNS Resolver>General Settings update the web dns record with {subnets_dict['docker_ip']}",
    ]
    print_steps("pfsense", pfsense_steps)


if __name__ == "__main__":
    try:
        split_ipv6_range(sys.argv[1])
    except InvalidIPv6Range as e:
        print(e)
        sys.exit(1)
