# HubSpot Contacts to Google Sheets

This repository contains a Ballerina project that retrieves contacts from HubSpot and exports them to Google Sheets.

## Setup

1. Install [Ballerina](https://ballerina.io/).
2. Configure `Config.toml` with HubSpot and Google API credentials.
3. Start from `Config.toml.example`, then copy values into `Config.toml`.

## Configuration
Update `Config.toml` with the hardcoded values for HubSpot API key, Google Sheets ID, and other necessary parameters.

### How to fill `Config.toml`

Use `Config.toml.example` as a template.

1. Set HubSpot key:
`hubspotAccessToken`
2. Set Google OAuth values:
`googleClientId`, `googleClientSecret`, `googleRefreshToken`
3. Set target spreadsheet:
`spreadsheetId`
4. Set sheet routing:
`sheetName`, `leadSheetName`, `customerSheetName`, `defaultSheetName`
5. Optional filter:
`contactFilterProperty`, `contactFilterValue`
6. Runtime tuning:
`scheduleIntervalSeconds`, `maxRows`

If any value is wrong, the terminal now prints a clear `---- Hint ----` message.

## Architecture

HubSpot API
     ↓
Ballerina Integration Service
     ↓
Google Sheets API

## Example Output
Email | First Name | Last Name | Phone
---------------------------------------
test@email.com | John | Doe | 123456

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
- **Row Limit Control**: Configurable maximum rows to process per run (0 = unlimited, only applies to incremental sync)

## Notes

- Sensitive configuration files are ignored via `.gitignore`.

