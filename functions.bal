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

// Export contacts to Google Sheet
function exportContactsToSheet(Contact[] contacts) returns error? {
    io:println("Exporting contacts to Google Sheet...");
    
    // Ensure header row exists before exporting data
    check ensureHeaderRow();
    
    int successCount = 0;
    int errorCount = 0;
    
    foreach Contact contact in contacts {
        ContactProperties props = contact.properties;
        
        // Dynamically build row data based on configured fields
        (string|int|decimal)[] rowData = [];
        
        foreach string fieldName in fields {
            // Extract property value dynamically
            string fieldValue = getContactPropertyValue(props, fieldName);
            rowData.push(fieldValue);
        }
        
        // Append row to Google Sheet
        error? result = sheetsClient->appendRowToSheet(spreadsheetId, sheetName, rowData);
        
        if result is error {
            io:println(string `Error exporting contact ${contact.id}: ${result.message()}`);
            errorCount += 1;
        } else {
            successCount += 1;
        }
    }
    
    io:println(string `Export completed: ${successCount} successful, ${errorCount} failed`);
}
