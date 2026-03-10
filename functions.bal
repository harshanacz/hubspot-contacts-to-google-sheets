import ballerina/io;
import ballerinax/hubspot.crm.obj.contacts as hubspotcontacts;
import ballerinax/googleapis.sheets;

// Check if the sheet is empty and insert headers if needed
function ensureHeaderRow(string targetSheet) returns error? {

    sheets:Range|error rangeResult = sheetsClient->getRange(spreadsheetId, targetSheet, "A1:Z1");

    if rangeResult is error {
        io:println(string `Sheet '${targetSheet}' appears empty. Inserting header row...`);
        check insertHeaderRow(targetSheet);
        return;
    }

    sheets:Range rangeData = rangeResult;

    if rangeData.values.length() == 0 {
        io:println(string `Sheet '${targetSheet}' is empty. Inserting headers...`);
        check insertHeaderRow(targetSheet);
    } else {
        io:println(string `Header row already exists in '${targetSheet}'.`);
    }
}

// Insert header row
function insertHeaderRow(string targetSheet) returns error? {

    (string|int|decimal)[] headers = [];

    foreach string fieldName in fields {
        headers.push(convertFieldToHeader(fieldName));
    }

    headers.push("Last Synced");

    check sheetsClient->appendRowToSheet(spreadsheetId, targetSheet, headers);

    io:println(string `Header row inserted in '${targetSheet}'`);
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
    boolean hasContactFilter = contactFilterProperty.trim() != "" && contactFilterValue.trim() != "";
    
    if isIncrementalSync {
        io:println(string `Incremental sync started from ${lastSyncTime} (maxRows = ${maxRows})`);
    } else {
        io:println("Full sync started (maxRows ignored)");
    }

    if hasContactFilter {
        io:println(string `Contact filter active: ${contactFilterProperty} = ${contactFilterValue}`);
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
                    phone: getPropertyValue(props,"phone"),
                    lifecyclestage: getPropertyValue(props,"lifecyclestage")
                },
                createdAt: hubspotContact.createdAt,
                updatedAt: hubspotContact.updatedAt,
                archived: hubspotContact.archived ?: false
            };

            // Apply optional contact property filter.
            if hasContactFilter {
                string filterPropertyValue = getPropertyValue(props, contactFilterProperty).trim().toLowerAscii();
                if filterPropertyValue != contactFilterValue.trim().toLowerAscii() {
                    continue;
                }
            }
            
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
        "lifecyclestage" => {
            return properties.lifecyclestage ?: "";
        }
        _ => {
            return "";
        }
    }
}

// Fetch contacts page
function fetchContactsPage(string? afterCursor)
returns hubspotcontacts:CollectionResponseSimplePublicObjectWithAssociationsForwardPaging|error {

    string[] requestProperties = getHubSpotRequestProperties();

    if afterCursor is string {
        return hubspotClient->/.get(after = afterCursor, properties = requestProperties, 'limit = 100);
    }

    return hubspotClient->/.get(properties = requestProperties, 'limit = 100);
}

function getHubSpotRequestProperties() returns string[] {
    string[] requestProperties = [];

    foreach string fieldName in fields {
        requestProperties.push(fieldName);
    }

    string filterProperty = contactFilterProperty.trim();
    if filterProperty != "" {
        boolean alreadyIncluded = false;
        foreach string fieldName in requestProperties {
            if fieldName == filterProperty {
                alreadyIncluded = true;
                break;
            }
        }

        if !alreadyIncluded {
            requestProperties.push(filterProperty);
        }
    }

    boolean hasLifecycleStage = false;
    foreach string fieldName in requestProperties {
        if fieldName == "lifecyclestage" {
            hasLifecycleStage = true;
            break;
        }
    }

    if !hasLifecycleStage {
        requestProperties.push("lifecyclestage");
    }

    return requestProperties;
}

// Build email → row map
function buildEmailRowMap(string targetSheet) returns map<int>|error {

    map<int> emailRowMap = {};

    sheets:Range|error result =
        sheetsClient->getRange(spreadsheetId, targetSheet, "A:A");

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
function updateSheetRow(string targetSheet, int rowNumber, (string|int|decimal)[] rowData) returns error? {

    string endColumn = getColumnLetter(rowData.length());

    string range =
        string `A${rowNumber}:${endColumn}${rowNumber}`;

    sheets:Range updateRange = {
        a1Notation: range,
        values: [rowData]
    };

    check sheetsClient->setRange(spreadsheetId, targetSheet, updateRange);
}

function getTargetSheetName(Contact contact) returns string {
    string lifecycleStage = getContactPropertyValue(contact.properties, "lifecyclestage").trim().toLowerAscii();

    if lifecycleStage == "lead" {
        return leadSheetName;
    }

    if lifecycleStage == "customer" {
        return customerSheetName;
    }

    string configuredDefaultSheet = defaultSheetName.trim();
    if configuredDefaultSheet != "" {
        return configuredDefaultSheet;
    }

    return sheetName;
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

// Export contacts with UPSERT and return latest processed timestamp
function exportContactsToSheet(Contact[] contacts, string lastSyncTimestamp, boolean isFullSync) returns string|error {

    io:println("Exporting contacts to sheet...");
    map<map<int>> emailRowMapBySheet = {};

    int insertCount = 0;
    int updateCount = 0;
    int errorCount = 0;
    
    string latestTimestamp = lastSyncTimestamp;
    int processedCount = 0;
    
    boolean limitReached = false;

    foreach Contact contact in contacts {
        
        // Apply max row limit only during incremental sync runs.
        if !isFullSync && maxRows > 0 {
            if processedCount >= maxRows {
                io:println("Max row limit reached. Stopping export.");
                limitReached = true;
                break;
            }
        }

        ContactProperties props = contact.properties;
        string targetSheet = getTargetSheetName(contact);

        map<int>? existingSheetMap = emailRowMapBySheet[targetSheet];
        map<int> emailRowMap;
        if existingSheetMap is map<int> {
            emailRowMap = existingSheetMap;
        } else {
            check ensureHeaderRow(targetSheet);
            emailRowMap = check buildEmailRowMap(targetSheet);
            emailRowMapBySheet[targetSheet] = emailRowMap;
        }

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

        // Add per-row sync write timestamp as the final column.
        string lastSyncedAt = getCurrentTimestamp();
        rowData.push(lastSyncedAt);

        int? existingRow = emailRowMap[email];
        boolean upsertSucceeded = false;

        if existingRow is int {

            error? result =
                updateSheetRow(targetSheet, existingRow, rowData);

            if result is error {
                io:println(string `Update failed ${contact.id}`);
                errorCount += 1;
            } else {
                updateCount += 1;
                upsertSucceeded = true;
            }

        } else {

            error? result =
                sheetsClient->appendRowToSheet(
                    spreadsheetId,
                    targetSheet,
                    rowData
                );

            if result is error {
                io:println(string `Insert failed ${contact.id}`);
                errorCount += 1;
            } else {
                insertCount += 1;
                upsertSucceeded = true;
            }
        }
        
        if upsertSucceeded {
            processedCount += 1;
        }

        // Track the newest processed updatedAt timestamp.
        if upsertSucceeded && (latestTimestamp == "" || isNewerThan(contact.updatedAt, latestTimestamp)) {
            latestTimestamp = contact.updatedAt;
        }
    }

    string limitInfo = limitReached ? " (limit reached)" : "";
    io:println(
        string `Export finished → inserted ${insertCount}, updated ${updateCount}, failed ${errorCount}${limitInfo}`
    );
    
    return latestTimestamp;
}