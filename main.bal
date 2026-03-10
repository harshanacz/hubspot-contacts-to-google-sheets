import ballerina/io;

public function main() returns error? {
    io:println("Starting HubSpot to Google Sheets export...");
    
    // Step 1: Fetch contacts from HubSpot
    Contact[] contacts = check fetchHubSpotContacts();
    
    if contacts.length() == 0 {
        io:println("No contacts found in HubSpot");
        return;
    }
    
    // Step 2: Export contacts to Google Sheet
    check exportContactsToSheet(contacts);
    
    io:println("Export process completed successfully!");
}
