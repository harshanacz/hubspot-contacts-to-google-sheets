import ballerina/io;
import ballerinax/hubspot.crm.obj.contacts as hubspotcontacts;
import ballerinax/googleapis.sheets;

// Check if the sheet is empty and insert headers if needed
function ensureHeaderRow() returns error? {

    sheets:Range|error rangeResult = sheetsClient->getRange(spreadsheetId, sheetName, "A1:Z1");

    if rangeResult is error {
        io:println("Sheet appears empty. Inserting header row...");
        check insertHeaderRow();
        return;
    }

    sheets:Range rangeData = rangeResult;

    if rangeData.values.length() == 0 {
        io:println("Sheet empty. Inserting headers...");
        check insertHeaderRow();
    } else {
        io:println("Header row already exists.");
    }
}

// Insert header row
function insertHeaderRow() returns error? {

    (string|int|decimal)[] headers = [];

    foreach string fieldName in fields {
        headers.push(convertFieldToHeader(fieldName));
    }

    check sheetsClient->appendRowToSheet(spreadsheetId, sheetName, headers);

    io:println("Header row inserted");
}

// Convert field name to header
function convertFieldToHeader(string fieldName) returns string {

    match fieldName {
        "email" => {
            return "Email";
        }
        "firstname" => {
            return "First Name";
        }
        "lastname" => {
            return "Last Name";
        }
        "phone" => {
            return "Phone";
        }
        _ => {
            if fieldName.length() > 0 {
                return fieldName.substring(0,1).toUpperAscii() + fieldName.substring(1);
            }
            return fieldName;
        }
    }
}

// Fetch HubSpot contacts with optional incremental sync
function fetchHubSpotContacts(string lastSyncTime) returns Contact[]|error {

    Contact[] allContacts = [];
    string? afterCursor = ();
    
    boolean isIncrementalSync = lastSyncTime != "";
    
    if isIncrementalSync {
        io:println(string `Incremental sync started from ${lastSyncTime}`);
    } else {
        io:println("Full sync started");
    }

    while true {

        hubspotcontacts:CollectionResponseSimplePublicObjectWithAssociationsForwardPaging response =
            check fetchContactsPage(afterCursor);

        foreach var hubspotContact in response.results {

            record {|string?...;|} props = hubspotContact.properties;

            Contact contact = {
                id: hubspotContact.id,
                properties: {
                    email: getPropertyValue(props,"email"),
                    firstname: getPropertyValue(props,"firstname"),
                    lastname: getPropertyValue(props,"lastname"),
                    phone: getPropertyValue(props,"phone")
                },
                createdAt: hubspotContact.createdAt,
                updatedAt: hubspotContact.updatedAt,
                archived: hubspotContact.archived ?: false
            };
            
            // Filter contacts based on last sync timestamp
            if isIncrementalSync {
                if isNewerThan(contact.updatedAt, lastSyncTime) {
                    allContacts.push(contact);
                }
            } else {
                allContacts.push(contact);
            }
        }

        string? nextAfter = response.paging?.next?.after;

        if nextAfter is string {
            afterCursor = nextAfter;
        } else {
            break;
        }
    }

    io:println(string `Fetched ${allContacts.length()} contacts`);

    return allContacts;
}

// Extract property safely
function getPropertyValue(record {|string?...;|} properties, string key) returns string {
    return <string?>properties.get(key) ?: "";
}

// Contact property getter
function getContactPropertyValue(ContactProperties properties, string key) returns string {

    match key {
        "email" => {
            return properties.email ?: "";
        }
        "firstname" => {
            return properties.firstname ?: "";
        }
        "lastname" => {
            return properties.lastname ?: "";
        }
        "phone" => {
            return properties.phone ?: "";
        }
        _ => {
            return "";
        }
    }
}

// Fetch contacts page
function fetchContactsPage(string? afterCursor)
returns hubspotcontacts:CollectionResponseSimplePublicObjectWithAssociationsForwardPaging|error {

    if afterCursor is string {
        return hubspotClient->/.get(after = afterCursor, properties = fields, 'limit = 100);
    }

    return hubspotClient->/.get(properties = fields, 'limit = 100);
}

// Build email → row map
function buildEmailRowMap() returns map<int>|error {

    map<int> emailRowMap = {};

    sheets:Range|error result =
        sheetsClient->getRange(spreadsheetId, sheetName, "A:A");

    if result is error {
        io:println("No existing sheet data");
        return emailRowMap;
    }

    sheets:Range rangeData = result;

    int rowIndex = 1;

    foreach (int|string|decimal)[] row in rangeData.values {

        if rowIndex > 1 && row.length() > 0 {

            string email =
                row[0].toString().trim().toLowerAscii();

            if email != "" {
                emailRowMap[email] = rowIndex;
            }
        }

        rowIndex += 1;
    }

    io:println(string `Existing contacts in sheet: ${emailRowMap.length()}`);

    return emailRowMap;
}

// Update row
function updateSheetRow(int rowNumber,(string|int|decimal)[] rowData) returns error? {

    string endColumn = getColumnLetter(rowData.length());

    string range =
        string `A${rowNumber}:${endColumn}${rowNumber}`;

    sheets:Range updateRange = {
        a1Notation: range,
        values: [rowData]
    };

    check sheetsClient->setRange(spreadsheetId,sheetName,updateRange);
}

// Column index → letter
function getColumnLetter(int columnNumber) returns string {

    string[] alphabet = [
        "A","B","C","D","E","F","G","H","I","J","K","L","M",
        "N","O","P","Q","R","S","T","U","V","W","X","Y","Z"
    ];

    string columnLetter = "";
    int number = columnNumber;

    while number > 0 {

        int remainder = (number - 1) % 26;

        columnLetter =
            string `${alphabet[remainder]}${columnLetter}`;

        number = (number - 1) / 26;
    }

    return columnLetter;
}

// Export contacts with UPSERT and return latest timestamp
function exportContactsToSheet(Contact[] contacts) returns string|error {

    io:println("Exporting contacts to sheet...");

    check ensureHeaderRow();

    map<int> emailRowMap =
        check buildEmailRowMap();

    int insertCount = 0;
    int updateCount = 0;
    int errorCount = 0;
    
    string latestTimestamp = "";

    foreach Contact contact in contacts {

        ContactProperties props = contact.properties;

        string email =
            getContactPropertyValue(props,"email")
            .trim()
            .toLowerAscii();

        if email == "" {
            io:println(string `Skipping ${contact.id}: no email`);
            errorCount += 1;
            continue;
        }

        (string|int|decimal)[] rowData = [];

        foreach string fieldName in fields {

            string value =
                getContactPropertyValue(props,fieldName);

            rowData.push(value);
        }

        int? existingRow = emailRowMap[email];

        if existingRow is int {

            error? result =
                updateSheetRow(existingRow,rowData);

            if result is error {
                io:println(string `Update failed ${contact.id}`);
                errorCount += 1;
            } else {
                updateCount += 1;
            }

        } else {

            error? result =
                sheetsClient->appendRowToSheet(
                    spreadsheetId,
                    sheetName,
                    rowData
                );

            if result is error {
                io:println(string `Insert failed ${contact.id}`);
                errorCount += 1;
            } else {
                insertCount += 1;
            }
        }
        
        // Track the latest updatedAt timestamp
        if latestTimestamp == "" || isNewerThan(contact.updatedAt, latestTimestamp) {
            latestTimestamp = contact.updatedAt;
        }
    }

    io:println(
        string `Export finished → inserted ${insertCount}, updated ${updateCount}, failed ${errorCount}`
    );
    
    return latestTimestamp;
}