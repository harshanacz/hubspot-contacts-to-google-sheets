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
Start
  ↓
Load last sync timestamp
  ↓
Determine sync type
  ↓
Full sync (first run) OR Incremental sync
  ↓
Fetch HubSpot contacts
  ↓
Normalize email
  ↓
Check existing rows in Google Sheet
  ↓
Update row OR append row
  ↓
Track latest updatedAt timestamp
  ↓
Save last sync timestamp
  ↓
Wait for next scheduled run
```

## Features

- **Incremental Sync**: Only processes contacts modified since last run
- **UPSERT Logic**: Updates existing contacts, inserts new ones (by email)
- **Automatic Scheduling**: Runs at configurable intervals
- **Persistent State**: Tracks last sync timestamp across restarts

## Notes

- Sensitive configuration files are ignored via `.gitignore`.

