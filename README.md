# HubSpot Contacts to Google Sheets

This repository contains a Ballerina project that retrieves contacts from HubSpot and exports them to Google Sheets.

## Setup

1. Install [Ballerina](https://ballerina.io/).
2. Configure `Config.toml` with HubSpot and Google API credentials.

## Usage

```bash
bal run
```

## Flow

```text
HubSpot contacts
	↓
normalize email
	↓
check sheet
	↓
update row OR append row
```

## Notes

- Sensitive configuration files are ignored via `.gitignore`.

