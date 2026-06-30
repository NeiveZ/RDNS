# RDNS 

> Reverse DNS Scanner — PTR record lookup for single IPs and subnet ranges.

![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Kali-557C94?style=flat-square&logo=kalilinux&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)
![Status](https://img.shields.io/badge/Status-Active-brightgreen?style=flat-square)

---

## Overview

RDNS performs **reverse DNS lookups** against a single IP or a subnet range, resolving PTR records to discover hostnames. Useful during the recon phase to map IP addresses back to domain names and identify services, infrastructure patterns, and ownership.

---

## Features

- **Single IP and range modes** — test one IP or sweep an entire subnet range
- **Parallel queries** — configurable thread pool for fast sweeps
- **Fallback chain** — tries `host` → `dig` → `nslookup` automatically, uses whichever is available
- **Robust PTR parsing** — uses field-aware extraction instead of fragile `cut` column counting
- **Range validation** — catches invalid ranges (start > end) before running
- **Output to file** — saves results with timestamped header
- **Silent mode** — results only, suitable for piping into other tools

---

## Requirements

| Dependency | Purpose | Install |
|---|---|---|
| `bash 4.0+` | Script runtime | Pre-installed on Linux |
| `host` or `dig` or `nslookup` | PTR lookups | `apt install dnsutils` |

```bash
sudo apt install dnsutils
```

At least one of `host`, `dig`, or `nslookup` must be available. RDNS detects and uses whichever is installed.

---

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/NeiveZ/RDNS.git
cd RDNS
```

### 2. Make the script executable

```bash
chmod +x rdns.sh
```

### 3. (Optional) Install globally

```bash
sudo cp rdns.sh /usr/local/bin/rdns
```

---

## Usage

```
./rdns.sh -t <target> [options]

Options:
  -t, --target      Single IP or subnet prefix (required)
                    Single:  192.168.1.10
                    Range:   192.168.1  (requires --start and --end)
  -s, --start       Range start — last octet (e.g. 1)
  -e, --end         Range end   — last octet (e.g. 254)
  -T, --timeout     Query timeout in seconds (default: 3)
  -t2, --threads    Parallel queries in range mode (default: 20)
  -o, --output      Save results to file
  --silent          Results only — no header or summary
  -h, --help        Show this help
```

---

## Examples

**Single IP lookup:**
```bash
./rdns.sh -t 8.8.8.8
```

**Custom range:**
```bash
./rdns.sh -t 37.59.174 -s 224 -e 239
```

**Full /24 sweep:**
```bash
./rdns.sh -t 192.168.1 -s 1 -e 254
```

**Fast sweep, save results:**
```bash
./rdns.sh -t 10.0.0 -s 1 -e 254 -t2 50 -o results.txt
```

**Silent mode — pipe into other tools:**
```bash
./rdns.sh -t 192.168.1 -s 1 -e 254 --silent | grep "mail"
./rdns.sh -t 192.168.1 -s 1 -e 254 --silent | awk -F' -> ' '{print $2}' | sort
```

---

## Output

```
37.59.174.224-239  tool:host  ips:16  threads:20

[PTR] 37.59.174.224      → ns3012.ovh.net
[PTR] 37.59.174.225      → ns3013.ovh.net
[PTR] 37.59.174.230      → mail.example.com
[PTR] 37.59.174.235      → srv01.example.com

time: 4s
saved: results.txt
```

---

## Repository Structure

```
RDNS/
└── rdns.sh    # Main script
```

---

## Legal

For use only on systems you own or have explicit written authorization to test.
Unauthorized use against third-party systems is illegal.
