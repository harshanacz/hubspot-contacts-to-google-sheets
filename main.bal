import ballerina/io;
import ballerina/lang.runtime;

public function main() returns error? {
    io:println("---- HubSpot -> Google Sheets Sync Started ----");
    io:println(string `---- Scheduler interval: ${scheduleIntervalSeconds}s ----`);
    
    // Run scheduled export in infinite loop
    while true {
        io:println("---- Run Start ----");
        io:println("---- Fetching contacts from HubSpot ----");
        
        // Get the last sync timestamp
        string lastSyncTime = getLastSyncTimestamp();
        boolean isFullSync = lastSyncTime == "";
        
        // Step 1: Fetch contacts from HubSpot (with incremental sync)
        Contact[] contacts = check fetchHubSpotContacts(lastSyncTime);
        string latestTimestamp = lastSyncTime;
        
        if contacts.length() == 0 {
            io:println("---- No new or updated contacts found ----");

            if isFullSync {
                latestTimestamp = getCurrentTimestamp();
            }
        } else {
            // Step 2: Export contacts to Google Sheet and get latest timestamp
            io:println("---- Exporting contacts to Google Sheets ----");
            latestTimestamp = check exportContactsToSheet(contacts, lastSyncTime, isFullSync);
        }

        // Step 3: Save the latest timestamp for next run after processing finishes.
        if latestTimestamp != lastSyncTime {
            io:println("---- Saving sync checkpoint ----");
            check saveLastSyncTimestamp(latestTimestamp);
        }
        
        io:println("---- Run Completed ----");
        io:println(string `---- Waiting ${scheduleIntervalSeconds}s for next run ----`);
        
        // Sleep for configured interval
        runtime:sleep(<decimal>scheduleIntervalSeconds);
    }
}
