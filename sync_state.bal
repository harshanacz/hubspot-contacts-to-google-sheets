import ballerina/io;
import ballerina/file;
import ballerina/time;

// File to store the last sync timestamp
const string SYNC_STATE_FILE = "last_sync_timestamp.txt";

// Global variable to track current sync timestamp
string currentSyncTimestamp = lastSyncTimestamp;

// Get the last sync timestamp
function getLastSyncTimestamp() returns string {
    // First check if there's a persisted timestamp in file
    boolean|file:Error fileExistsResult = file:test(SYNC_STATE_FILE, file:EXISTS);
    if fileExistsResult is boolean && fileExistsResult {
        string|error fileContent = io:fileReadString(SYNC_STATE_FILE);
        if fileContent is string {
            string timestamp = fileContent.trim();
            if timestamp != "" {
                io:println(string `---- Loaded checkpoint from file: ${timestamp}`);
                return timestamp;
            }
        }
    }
    
    // Fall back to configurable value
    if currentSyncTimestamp != "" {
        io:println(string `---- Using configured checkpoint: ${currentSyncTimestamp}`);
        return currentSyncTimestamp;
    }
    
    io:println("---- No checkpoint found. Starting full sync");
    return "";
}

// Save the last sync timestamp to file.
// We advance the checkpoint by 1 ms so that the next incremental run
// uses `updatedAt >= checkpoint + 1ms` semantics, preventing contacts that
// share the exact latest timestamp from being silently skipped forever.
function saveLastSyncTimestamp(string timestamp) returns error? {
    time:Utc|error parsedTime = time:utcFromString(timestamp);
    string checkpointToSave = timestamp;
    if parsedTime is time:Utc {
        // Advance by 1 millisecond (0.001 seconds) so the next run's
        // "strictly after" filter does not re-skip same-millisecond contacts.
        time:Utc advanced = time:utcAddSeconds(parsedTime, 0.001d);
        checkpointToSave = time:utcToString(advanced);
    } else {
        io:println(string `---- Warning: could not advance checkpoint timestamp '${timestamp}': ${parsedTime.message()}. Saving as-is.`);
    }
    check io:fileWriteString(SYNC_STATE_FILE, checkpointToSave);
    currentSyncTimestamp = checkpointToSave;
    io:println(string `---- Saved checkpoint: ${checkpointToSave}`);
}

// Get current timestamp in ISO 8601 format
function getCurrentTimestamp() returns string {
    time:Utc currentTime = time:utcNow();
    string timestamp = time:utcToString(currentTime);
    return timestamp;
}

// Compare two ISO 8601 timestamps
function isNewerThan(string timestamp1, string timestamp2) returns boolean {
    if timestamp2 == "" {
        return true;
    }
    
    time:Utc|error time1 = time:utcFromString(timestamp1);
    time:Utc|error time2 = time:utcFromString(timestamp2);

    if time1 is time:Utc && time2 is time:Utc {
        decimal diff = time:utcDiffSeconds(time1, time2);
        return diff > 0d;
    }

    // Log the parse failure so it doesn't go unnoticed, then include the
    // contact to be safe (better to re-process than to silently drop it).
    if time1 is error {
        io:println(string `---- Warning: could not parse timestamp '${timestamp1}': ${time1.message()}. Including contact.`);
    }
    if time2 is error {
        io:println(string `---- Warning: could not parse checkpoint '${timestamp2}': ${time2.message()}. Including contact.`);
    }
    return true;
}
