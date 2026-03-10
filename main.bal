import ballerina/io;
import ballerina/lang.runtime;

public function main() returns error? {
    io:println(string `HubSpot to Google Sheets integration started with ${scheduleIntervalSeconds}s interval`);
    
    // Run scheduled export in infinite loop
    while true {
        io:println("Starting scheduled HubSpot export...");
        
        // Step 1: Fetch contacts from HubSpot
        Contact[] contacts = check fetchHubSpotContacts();
        
        if contacts.length() == 0 {
            io:println("No contacts found in HubSpot");
        } else {
            // Step 2: Export contacts to Google Sheet
            check exportContactsToSheet(contacts);
        }
        
        io:println("Export completed");
        io:println(string `Waiting for next run in ${scheduleIntervalSeconds} seconds...`);
        
        // Sleep for configured interval
        runtime:sleep(<decimal>scheduleIntervalSeconds);
    }
}
