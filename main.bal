import ballerina/io;
import ballerina/lang.runtime;

public function main() returns error? {
    io:println(string `HubSpot to Google Sheets integration started with ${scheduleIntervalSeconds}s interval`);
    
    // Run scheduled export in infinite loop
    while true {
        io:println("Starting scheduled HubSpot export...");
        
        // Get the last sync timestamp
        string lastSyncTime = getLastSyncTimestamp();
        
        // Step 1: Fetch contacts from HubSpot (with incremental sync)
        Contact[] contacts = check fetchHubSpotContacts(lastSyncTime);
        
        if contacts.length() == 0 {
            io:println("No new or updated contacts found");
        } else {
            // Step 2: Export contacts to Google Sheet and get latest timestamp
            string latestTimestamp = check exportContactsToSheet(contacts);
            
            // Step 3: Save the latest timestamp for next run
            if latestTimestamp != "" {
                check saveLastSyncTimestamp(latestTimestamp);
            } else if lastSyncTime == "" {
                // If this was a full sync with no contacts, save current time
                string currentTime = getCurrentTimestamp();
                check saveLastSyncTimestamp(currentTime);
            }
        }
        
        io:println("Export completed");
        io:println(string `Waiting for next run in ${scheduleIntervalSeconds} seconds...`);
        
        // Sleep for configured interval
        runtime:sleep(<decimal>scheduleIntervalSeconds);
    }
}
