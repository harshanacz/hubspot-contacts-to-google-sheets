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

// Lifecycle-based Sheet Routing Configuration
configurable string leadSheetName = "Leads";
configurable string customerSheetName = "Customers";
configurable string defaultSheetName = "";

// Field Mapping Configuration
configurable string[] fields = ["email", "firstname", "lastname", "phone"];

// Scheduling Configuration
configurable int scheduleIntervalSeconds = 15;

// Incremental Sync Configuration
configurable string lastSyncTimestamp = "";

// Optional Contact Filter Configuration
configurable string contactFilterProperty = "";
configurable string contactFilterValue = "";

// Row Limit Configuration
configurable int maxRows = 2;
