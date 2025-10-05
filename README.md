# Bug Bounty Asset Discovery Pipeline

A modular bash-based reconnaissance automation tool for bug bounty hunters. Automates domain enumeration, URL discovery, JavaScript file collection, and asset categorization through a structured 6-phase pipeline.

## Table of Contents

-   [Bug Bounty Asset Discovery Pipeline](#bug-bounty-asset-discovery-pipeline)
    -   [Table of Contents](#table-of-contents)
    -   [Features](#features)
    -   [Project Structure](#project-structure)
    -   [Installation](#installation)
        -   [Required Tools](#required-tools)
        -   [Environment Setup](#environment-setup)
    -   [Usage](#usage)
        -   [Basic Command](#basic-command)
        -   [Options](#options)
        -   [Examples](#examples)
    -   [Output Files](#output-files)
        -   [Primary Output Files](#primary-output-files)
        -   [Intermediate Files](#intermediate-files)
    -   [Pipeline Steps](#pipeline-steps)
        -   [Step 1: Domain Discovery Phase](#step-1-domain-discovery-phase)
        -   [Step 2: URL Discovery Phase](#step-2-url-discovery-phase)
        -   [Step 3: URL Consolidation Phase](#step-3-url-consolidation-phase)
        -   [Step 4: URL Categorization Phase](#step-4-url-categorization-phase)
        -   [Step 5: JavaScript Discovery Phase](#step-5-javascript-discovery-phase)
        -   [Step 6: Asset URLs Validation Phase](#step-6-asset-urls-validation-phase)
    -   [Configuration](#configuration)
    -   [Sample Output](#sample-output)
    -   [Disclaimer](#disclaimer)

## Features

-   **Multi-source Domain Enumeration**: Aggregate results from 8+ subdomain discovery tools
-   **Comprehensive URL Discovery**: Crawl and discover URLs from multiple sources including Wayback Machine
-   **JavaScript Asset Collection**: Automated discovery and validation of JavaScript files
-   **Intelligent URL Categorization**: Automatically categorize sensitive parameters, API endpoints, and static files
-   **Optional Subdomain Bruteforcing**: Enable dnsx or shuffledns for aggressive enumeration
-   **Screenshot Capability**: Visual documentation of discovered domains
-   **Parallel Processing**: Faster results through concurrent execution
-   **Modular Architecture**: Clean separation of concerns for easy maintenance

## Project Structure

```
.
├── main.sh                 # Entry point and argument parsing
├── lib/
│   ├── config.sh          # Configuration variables
│   ├── utils.sh           # Helper functions and utilities
│   └── cleanup.sh         # Cleanup routines
└── steps/
    ├── domains.sh         # Step 1: Domain discovery
    ├── urls.sh            # Step 2: URL discovery
    ├── urls_con.sh        # Step 3: URL consolidation
    ├── urls_cat.sh        # Step 4: URL categorization
    ├── js.sh              # Step 5: JavaScript discovery
    └── validation.sh      # Step 6: Asset validation
```

## Installation

### Required Tools

Install the following tools before running the pipeline:

**Go-based tools:**

```bash
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/tlsx/cmd/tlsx@latest
go install -v github.com/projectdiscovery/katana/cmd/katana@latest
go install -v github.com/projectdiscovery/chaos-client/cmd/chaos@latest
go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest
go install -v github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest
go install -v github.com/tomnomnom/assetfinder@latest
go install -v github.com/003random/getJS@latest
go install -v github.com/hakluke/hakrawler@latest
go install -v github.com/sensepost/gowitness@latest
```

**Python-based tools:**

```bash
pip install waymore
git clone https://github.com/devanshbatham/paramspider
cd paramspider
pip install .
```

**Other tools:**

-   **findomain**: Download from [https://github.com/findomain/findomain](https://github.com/findomain/findomain)
-   **jq**: `apt install jq` or `brew install jq`
-   **curl**: Usually pre-installed

### Environment Setup

Configure the following environment variables:

```bash
# Required for chaos tool (get your API key from https://chaos.projectdiscovery.io)
export CHAOS_API_KEY="your_projectdiscovery_api_key"
```

**Make the variable persistent:**

```bash
echo 'export CHAOS_API_KEY="your_api_key"' >> ~/.bashrc
source ~/.bashrc
```

**Make script executable:**

```bash
chmod +x main.sh
```

## Usage

### Basic Command

```bash
./main.sh <domain> [options]
```

### Options

| Short | Long            | Description                                            | Required                          |
| ----- | --------------- | ------------------------------------------------------ | --------------------------------- |
| `-ss` | `--screenshots` | Take screenshots of discovered domains using gowitness | No                                |
| `-dx` | `--dnsx`        | Enable dnsx for subdomain bruteforcing                 | No                                |
| `-sd` | `--shuffledns`  | Enable shuffledns for subdomain bruteforcing           | No                                |
| `-w`  | `--wordlist`    | Path to wordlist file                                  | Yes (when `-dx` or `-sd` is used) |
| `-r`  | `--resolvers`   | Path to DNS resolvers file                             | Yes (when `-sd` is used)          |
| `-h`  | `--help`        | Show help message                                      | No                                |

### Examples

**Basic scan:**

```bash
./main.sh example.com
```

**Scan with screenshots:**

```bash
./main.sh example.com -ss
```

**Scan with dnsx bruteforcing:**

```bash
./main.sh example.com -dx -w /path/to/subdomains.txt
```

**Scan with shuffledns bruteforcing:**

```bash
./main.sh example.com -sd -w /path/to/subdomains.txt -r /path/to/resolvers.txt
```

**Full scan with all options:**

```bash
./main.sh example.com -ss -dx -w /path/to/subdomains.txt
```

**Full scan with shuffledns:**

```bash
./main.sh example.com -ss -sd -w /path/to/subdomains.txt -r /path/to/resolvers.txt
```

## Output Files

All results are saved in `scope_<domain>/` directory.

### Primary Output Files

| File                   | Description                                                        |
| ---------------------- | ------------------------------------------------------------------ |
| `domains.txt`          | Filtered in-scope resolved domains                                 |
| `urls.txt`             | All discovered and filtered URLs                                   |
| `sen-param-urls.txt`   | URLs containing sensitive parameters (auth, token, password, etc.) |
| `api-urls.txt`         | API endpoints and GraphQL URLs                                     |
| `static-urls-live.txt` | Live static assets (JS, CSS, images, documents)                    |
| `download.txt`         | Copy of static-urls-live.txt for batch downloading                 |

### Intermediate Files

| File                   | Source                                     |
| ---------------------- | ------------------------------------------ |
| `domains-raw.txt`      | All discovered domains (before filtering)  |
| `domains-resolved.txt` | All resolved domains (before filtering)    |
| `raw-urls.txt`         | All URLs before filtering                  |
| `subfinder.txt`        | subfinder results                          |
| `findomain.txt`        | findomain results                          |
| `assetfinder.txt`      | assetfinder results                        |
| `tlsx-domains.txt`     | tlsx certificate transparency results      |
| `crtsh.txt`            | crt.sh certificate transparency results    |
| `chaos.txt`            | chaos dataset results                      |
| `dnsx.txt`             | dnsx bruteforce results (if enabled)       |
| `shuffledns.txt`       | shuffledns bruteforce results (if enabled) |
| `wurls.txt`            | waymore (Wayback Machine) results          |
| `kurls.txt`            | katana crawl results                       |
| `purls.txt`            | paramspider results                        |
| `hurls.txt`            | hakrawler results                          |
| `getjs-urls-raw.txt`   | getJS results                              |

## Pipeline Steps

### Step 1: Domain Discovery Phase

Discovers subdomains using multiple enumeration techniques:

-   **subfinder**: Passive subdomain enumeration from multiple sources
-   **findomain**: Fast subdomain enumeration with multiple APIs
-   **assetfinder**: Discovers domains from various sources
-   **tlsx**: Certificate transparency log analysis
-   **crt.sh**: Certificate transparency search
-   **chaos**: ProjectDiscovery's dataset
-   **dnsx**: DNS bruteforcing (optional, requires `-dx` flag and wordlist)
-   **shuffledns**: Fast DNS bruteforcing (optional, requires `-sd` flag, wordlist, and resolvers)

**Output**: Resolved and filtered domains saved to `domains.txt`

### Step 2: URL Discovery Phase

Crawls discovered domains and collects URLs:

-   **waymore**: Fetches URLs from Wayback Machine archives
-   **katana**: Advanced web crawler with JavaScript rendering
-   **paramspider**: Discovers URLs with parameters
-   **hakrawler**: Fast web crawler for URL discovery

**Output**: Raw URLs from all sources

### Step 3: URL Consolidation Phase

Merges and filters collected URLs:

-   Combines URLs from all sources
-   Filters invalid URLs and patterns
-   Removes tracking parameters (utm\_\*, gclid, fbclid)
-   Limits URL depth (max 5 levels)
-   Limits query parameters (max 5 per URL)
-   Removes URLs longer than 2048 characters

**Output**: Clean, filtered URLs saved to `urls.txt`

### Step 4: URL Categorization Phase

Categorizes URLs into actionable groups:

-   **Sensitive URLs**: Contains parameters like `token`, `key`, `secret`, `password`, `auth`, `session`, `jwt`, `api_key`, `oauth`, `callback`, etc.
-   **API Endpoints**: Matches patterns like `api.domain.com`, `/api/`, `/graphql`, `/v[1-6]/`, etc.
-   **Static Files**: JavaScript, CSS, documents, images, archives, fonts, media files

**Output**: Categorized URLs in separate files for focused testing

### Step 5: JavaScript Discovery Phase

Discovers and collects JavaScript files:

-   Uses **getJS** to extract JavaScript file references
-   Filters in-scope JavaScript files only
-   Combines with static files from previous steps
-   Validates domain scope

**Output**: Complete list of in-scope static assets

### Step 6: Asset URLs Validation Phase

Validates and confirms live assets:

-   Uses **httpx** to check URL responsiveness
-   Filters out dead/unreachable URLs
-   Creates final validated asset list
-   Prepares download list for further analysis

**Output**: Validated live static assets ready for analysis

## Configuration

Modify `lib/config.sh` to customize default behavior:

```bash
CRAWL_DEPTH=2              # Katana crawl depth (1-5 recommended)
TAKE_SCREENSHOTS=false     # Enable/disable screenshots by default
RUN_DNSX=false            # Enable/disable dnsx by default
RUN_SHUFFLEDNS=false      # Enable/disable shuffledns by default
```

## Sample Output

The pipeline outputs detailed results for every stage, including tool-by-tool discoveries, filtering progress, and categorized statistics.

```
┌──(jay@Jays-MacBook-Pro)-[~/programs/hackerone/example]
└─$ ./main.sh example.com

[1] Domain discovery phase
[~] Looking for domains...
[+] [crt.sh] 0 domains found
[+] [chaos] 138 domains found
[+] [subfinder] 177 domains found
[+] [assetfinder] 25 domains found
[+] [findomain] 45 domains found
[+] [tlsx] 16 assets found
[+] Found 75/217 reponsive domains
[+] Filtered 61 domains as targets

[2] URL discovery phase
[~] Looking for URLs...
[+] [waymore] 453989 URLs collected
[+] [hakrawler] 722 URLs collected
[+] [paramspider] 28 URLs collected
[+] [katana] 4901 URLs collected
[+] Total collected: 459640 URLs

[3] URL consolidation phase
[~] Merging collected URLs...
[~] Filtering valid URLs...
[!] Total removed: 83004 URLs
[+] Total filtered: 373482 URLs

[4] URL categorization phase
[~] Extracting URLs...
[+] API endpoints: 6 entries
[+] Static file URLs: 1040 entries
[+] Sensitive URLs: 5 entries

[5] JavaScript discovery phase
[~] Looking for JavaScript files...
[+] [getjs] 12 in-scope URLs found
[+] Total found: 1051 URLs

[6] Asset URLs validation phase
[~] Checking for responsive URLs...
[+] [static] 892 URLs resolved

[+] Domain Enumeration
| subfinder: 177
| findomain: 45
| assetfinder: 25
| tlsx: 16
| crt.sh: 0
| chaos: 138
| dnsx: 0
| shuffledns: 0
| Total unique: 217
| Resolved domains: 75
| Filtered domains: 61

[+] URL Enumeration
| waymore: 453989
| katana: 4901
| paramspider: 28
| hakrawler: 696
| Raw unique URLs: 456486
| Filtered URLs: 373482

[+] Categorized URLs
| Sensitive URLs: 5
| API endpoints: 6
| Static file URLs: 1051
| Resolved static URLs: 892
| Total URLs found: 903
```

## Disclaimer

Use responsibly. Only scan domains you have permission to audit.
