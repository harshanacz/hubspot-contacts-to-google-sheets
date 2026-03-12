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
// Each lifecycle stage maps to a sheet name.
// Set multiple stages to the same name to merge them into one sheet.
configurable string subscriberSheetName = "Subscribers";
configurable string leadSheetName = "Leads";
configurable string marketingqualifiedleadSheetName = "MQLs";
configurable string salesqualifiedleadSheetName = "SQLs";
configurable string opportunitySheetName = "Opportunities";
configurable string customerSheetName = "Customers";
configurable string evangelistSheetName = "Evangelists";
configurable string otherSheetName = "Others";
configurable string defaultSheetName = "Sheet1";

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
