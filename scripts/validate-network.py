#!/usr/bin/env python3
"""Valida somente IPv4; não inventa endereços ou servidores DNS."""
import ipaddress
import sys
mode, address, gateway, dns = sys.argv[1:]
try:
    if mode not in ('static', 'dhcp'):
        raise ValueError('modo inválido')
    if mode == 'static':
        interface = ipaddress.IPv4Interface(address)
        gw = ipaddress.IPv4Address(gateway)
        if gw not in interface.network or gw == interface.ip:
            raise ValueError('gateway deve pertencer à sub-rede e diferir do IP da VM')
        if not dns:
            raise ValueError('DNS obrigatório em modo static')
    elif address or gateway:
        raise ValueError('ADDRESS/GATEWAY devem estar vazios em DHCP')
    for server in dns.split(',') if dns else []:
        ipaddress.IPv4Address(server)
except ValueError as exc:
    sys.exit(f'Configuração de rede inválida: {exc}')
