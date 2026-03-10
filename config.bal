// HubSpot Configuration
configurable string hubspotAccessToken = ?;

// Google Sheets OAuth Configuration
configurable string googleClientId = ?;
configurable string googleClientSecret = ?;
configurable string googleRefreshToken = ?;
configurable string googleRefreshUrl = "https://oauth2.googleapis.com/token";

// Google Sheet Details
configurable string spreadsheetId = ?;
configurable string sheetName = ?;

// Field Mapping Configuration
configurable string[] fields = ["email", "firstname", "lastname", "phone"];

// Scheduling Configuration
configurable int scheduleIntervalSeconds = 5;
