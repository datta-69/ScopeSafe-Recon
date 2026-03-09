# ScopeSafe-Recon

A professional Bash-based penetration testing toolkit for Linux environments.

> Disclaimer: For educational and authorized penetration testing only.

## Features

- Target reconnaissance
- Multi-engine port scanning (Nmap + optional Naabu/RustScan/Masscan)
- Nmap profile pack (Quick, Standard, Full, Web, Safe)
- Multi-source subdomain enumeration (Subfinder/Amass/Assetfinder/DNS tools)
- Directory discovery (FFUF/Gobuster/Dirb or fallback checks)
- Web technology detection (WhatWeb + optional WAF and HTTP probes)
- Full auto recon mode
- Consolidated report generation
- Non-interactive automation mode (`--target --full-auto`)
- Resume mode for interrupted runs (`--resume`)
- Scope-file validation for authorized programs (`scope.txt`)
- URL and JS endpoint mining phase
- Timestamped output directories and logs
- Cross-Linux support (Kali, Debian/Ubuntu, Fedora/RHEL, Arch, OpenSUSE)

## Project Structure

```text
ScopeSafe-Recon/
├── toolkit.sh
├── modules/
│   ├── recon.sh
│   ├── portscan.sh
│   ├── dirscan.sh
│   └── subdomain.sh
├── core/
│   ├── colors.sh
│   ├── banner.sh
│   └── utils.sh
├── wordlists/
│   └── common_dirs.txt
├── profiles/
│   ├── quick.conf
│   ├── standard.conf
│   └── deep.conf
├── scope.txt.example
├── results/
│   └── .gitkeep
├── install.sh
├── README.md
└── LICENSE
```

## Supported Tools

The toolkit integrates with:

- `nmap`
- `dig`
- `curl`
- `whatweb`
- `subfinder`, `amass`, `assetfinder` (optional)
- `dnsrecon`, `dnsenum` (optional)
- `ffuf`, `dirb`, `gobuster` (optional)
- `naabu`, `rustscan`, `masscan` (optional)
- `wafw00f`, `httpx`, `theHarvester` (optional)
- `gau`, `waybackurls` (optional)

If tools are missing, the toolkit prints warnings and uses fallback logic where possible.

## Installation (Linux)

```bash
git clone https://github.com/datta-69/ScopeSafe-Recon.git

cd ScopeSafe-Recon
chmod +x install.sh
./install.sh
```

Manual run without installer:

```bash
chmod +x toolkit.sh core/*.sh modules/*.sh
./toolkit.sh
```

## Usage

Run:

```bash
./toolkit.sh
```

Menu options:

1. Target Reconnaissance
2. Port Scanning
3. Subdomain Enumeration
4. Directory Discovery
5. Web Technology Detection
6. URL/JS Mining
7. Full Auto Recon Mode
8. Generate Report
9. Exit

Automation mode:

```bash
./toolkit.sh --target example.com --full-auto --profile deep --resume
```

Common CLI options:

- `--target <domain-or-ip>`
- `--full-auto`
- `--profile quick|standard|deep`
- `--resume`
- `--scope-file <path>`
- `--wordlist <path>`
- `--timeout <seconds>`
- `--max-parallel <n>`

## Output Layout

Results are saved under:

- `results/<target>/<timestamp>/` (run-specific output)
- `results/<target>/` (latest copied outputs)

Main files:

- `recon.txt`
- `portscan.txt`
- `subdomains.txt`
- `dirs.txt`
- `webtech.txt`
- `urls.txt`
- `js_endpoints.txt`
- `report.txt`
- `toolkit.log`

## Full Auto Recon Flow

When Full Auto mode is selected, the toolkit runs:

1. Recon
2. Subdomain scan
3. Port scan
4. Directory scan
5. Web technology detection
6. URL/JS mining
7. Report generation

## Example

```bash
./toolkit.sh
# set target when prompted (example.com), choose nmap profile when scanning
# choose option 7 for Full Auto Recon
```

Then review:

```bash
ls -la results/example.com/
cat results/example.com/portscan.txt
cat results/example.com/report.txt

# non-interactive
./toolkit.sh --target example.com --full-auto --profile standard
```

## Notes

- Designed for Kali Linux and other Debian/RHEL/Arch/OpenSUSE based systems.
- Some scans require root privileges for best results (for example, Nmap OS detection).
- Always scan only systems you own or have written permission to test.
