import ballerina/io;
import ballerinax/hubspot.crm.obj.contacts as hubspotcontacts;
import ballerinax/googleapis.sheets;

// Check if the sheet is empty and insert headers if needed
function ensureHeaderRow() returns error? {
    // Try to get the first row to check if sheet has data
    sheets:Range|error rangeResult = sheetsClient->getRange(spreadsheetId, sheetName, "A1:Z1");
    
    if rangeResult is error {
        // If error occurs, assume sheet is empty or doesn't exist
        io:println("Sheet appears to be empty. Inserting header row...");
        check insertHeaderRow();
        return;
    }
    
    sheets:Range rangeData = rangeResult;
    
    // Check if the range has any values
    if rangeData.values.length() == 0 {
        io:println("Sheet is empty. Inserting header row...");
        check insertHeaderRow();
    } else {
        io:println("Sheet already contains data. Skipping header insertion.");
    }
}

// Insert header row based on configured fields
function insertHeaderRow() returns error? {
    // Create header labels from field names
    (string|int|decimal)[] headers = [];
    
    foreach string fieldName in fields {
        // Convert field names to readable headers
        string headerLabel = convertFieldToHeader(fieldName);
        headers.push(headerLabel);
    }
    
    // Append header row to sheet
    check sheetsClient->appendRowToSheet(spreadsheetId, sheetName, headers);
    io:println("Header row inserted successfully");
}

// Convert field name to readable header label
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
            // Capitalize first letter for unknown fields
            if fieldName.length() > 0 {
                string firstChar = fieldName.substring(0, 1).toUpperAscii();
                string restChars = fieldName.substring(1);
                return firstChar + restChars;
            }
            return fieldName;
        }
    }
}

// Fetch all contacts from HubSpot
function fetchHubSpotContacts() returns Contact[]|error {
    Contact[] allContacts = [];
    string? afterCursor = ();
    
    // Fetch contacts with pagination
    while true {
        hubspotcontacts:CollectionResponseSimplePublicObjectWithAssociationsForwardPaging response = check fetchContactsPage(afterCursor);
        
        foreach var hubspotContact in response.results {
            record {|string?...;|} hubspotProperties = hubspotContact.properties;

            Contact mappedContact = {
                id: hubspotContact.id,
                properties: {
                    email: getPropertyValue(hubspotProperties, "email"),
                    firstname: getPropertyValue(hubspotProperties, "firstname"),
                    lastname: getPropertyValue(hubspotProperties, "lastname"),
                    phone: getPropertyValue(hubspotProperties, "phone")
                },
                createdAt: hubspotContact.createdAt,
                updatedAt: hubspotContact.updatedAt,
                archived: hubspotContact.archived ?: false
            };

            allContacts.push(mappedContact);
        }
        
        // Check if there are more pages
        string? nextAfter = response.paging?.next?.after;
        if nextAfter is string {
            afterCursor = nextAfter;
        } else {
            break;
        }
    }
    
    io:println(string `Fetched ${allContacts.length()} contacts from HubSpot`);
    return allContacts;
}

// Extract property value from HubSpot properties map
function getPropertyValue(record {|string?...;|} properties, string key) returns string {
    return <string?>properties.get(key) ?: "";
}

// Overloaded version for ContactProperties record
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

function fetchContactsPage(string? afterCursor) returns hubspotcontacts:CollectionResponseSimplePublicObjectWithAssociationsForwardPaging|error {
    if afterCursor is string {
        return hubspotClient->/.get(after = afterCursor, properties = fields, 'limit = 100);
    }

    return hubspotClient->/.get(properties = fields, 'limit = 100);
}

// Build email to row index map from existing sheet data
function buildEmailRowMap() returns map<int>|error {
    map<int> emailRowMap = {};
    
    // Read all existing data from the sheet
    sheets:Range|error rangeResult = sheetsClient->getRange(spreadsheetId, sheetName, "A:Z");
    
    if rangeResult is error {
        // If error, assume sheet is empty or doesn't exist
        io:println("No existing data found in sheet");
        return emailRowMap;
    }
    
    sheets:Range rangeData = rangeResult;
    
    // Skip header row (index 0) and build map from data rows
    int rowIndex = 1;
    foreach (int|string|decimal)[] row in rangeData.values {
        if rowIndex > 1 && row.length() > 0 {
            // Email is in column A (index 0)
            string emailValue = row[0].toString();
            if emailValue.trim() != "" {
                emailRowMap[emailValue] = rowIndex;
            }
        }
        rowIndex += 1;
    }
    
    io:println(string `Found ${emailRowMap.length()} existing contacts in sheet`);
    return emailRowMap;
}

// Update an existing row in the sheet
function updateSheetRow(int rowNumber, (string|int|decimal)[] rowData) returns error? {
    // Calculate the column range based on number of fields
    string endColumn = getColumnLetter(rowData.length());
    string rangeNotation = string `A${rowNumber}:${endColumn}${rowNumber}`;
    
    // Create Range record with the data
    sheets:Range updateRange = {
        a1Notation: rangeNotation,
        values: [rowData]
    };
    
    // Update the row
    check sheetsClient->setRange(spreadsheetId, sheetName, updateRange);
}

// Convert column number to letter (1=A, 2=B, etc.)
function getColumnLetter(int columnNumber) returns string {
    string columnLetter = "";
    int number = columnNumber;
    string[] alphabet = [
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
        "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"
    ];
    
    while number > 0 {
        int remainder = (number - 1) % 26;
        columnLetter = string `${alphabet[remainder]}${columnLetter}`;
        number = (number - 1) / 26;
    }
    
    return columnLetter;
}

// Export contacts to Google Sheet with UPSERT logic
function exportContactsToSheet(Contact[] contacts) returns error? {
    io:println("Exporting contacts to Google Sheet...");
    
    // Ensure header row exists before exporting data
    check ensureHeaderRow();
    
    // Build email to row index map from existing data
    map<int> emailRowMap = check buildEmailRowMap();
    
    int insertCount = 0;
    int updateCount = 0;
    int errorCount = 0;
    
    foreach Contact contact in contacts {
        ContactProperties props = contact.properties;
        
        // Get email for this contact
        string emailValue = getContactPropertyValue(props, "email");
        
        // Skip contacts without email
        if emailValue.trim() == "" {
            io:println(string `Skipping contact ${contact.id}: no email address`);
            errorCount += 1;
            continue;
        }
        
        // Dynamically build row data based on configured fields
        (string|int|decimal)[] rowData = [];
        
        foreach string fieldName in fields {
            // Extract property value dynamically
            string fieldValue = getContactPropertyValue(props, fieldName);
            rowData.push(fieldValue);
        }
        
        // Check if email already exists in sheet
        int? existingRowNumber = emailRowMap[emailValue];
        
        if existingRowNumber is int {
            // Update existing row
            error? result = updateSheetRow(existingRowNumber, rowData);
            
            if result is error {
                io:println(string `Error updating contact ${contact.id}: ${result.message()}`);
                errorCount += 1;
            } else {
                updateCount += 1;
            }
        } else {
            // Append new row
            error? result = sheetsClient->appendRowToSheet(spreadsheetId, sheetName, rowData);
            
            if result is error {
                io:println(string `Error inserting contact ${contact.id}: ${result.message()}`);
                errorCount += 1;
            } else {
                insertCount += 1;
            }
        }
    }
    
    io:println(string `Export completed: ${insertCount} inserted, ${updateCount} updated, ${errorCount} failed`);
}
