import ballerina/io;
import ballerina/lang.runtime;

public function main() returns error? {
    io:println(string `HubSpot to Google Sheets integration started with ${scheduleIntervalSeconds}s interval`);
    
    // Run scheduled export in infinite loop
    while true {
        io:println("Starting scheduled HubSpot export...");
        
        // Get the last sync timestamp
        string lastSyncTime = getLastSyncTimestamp();
        boolean isFullSync = lastSyncTime == "";
        
        // Step 1: Fetch contacts from HubSpot (with incremental sync)
        Contact[] contacts = check fetchHubSpotContacts(lastSyncTime);
        string latestTimestamp = lastSyncTime;
        
        if contacts.length() == 0 {
            io:println("No new or updated contacts found");

            if isFullSync {
                latestTimestamp = getCurrentTimestamp();
            }
        } else {
            // Step 2: Export contacts to Google Sheet and get latest timestamp
            latestTimestamp = check exportContactsToSheet(contacts, lastSyncTime, isFullSync);
        }

        // Step 3: Save the latest timestamp for next run after processing finishes.
        if latestTimestamp != lastSyncTime {
            check saveLastSyncTimestamp(latestTimestamp);
        }
        
        io:println("Export completed");
        io:println(string `Waiting for next run in ${scheduleIntervalSeconds} seconds...`);
        
        // Sleep for configured interval
        runtime:sleep(<decimal>scheduleIntervalSeconds);
    }
}
