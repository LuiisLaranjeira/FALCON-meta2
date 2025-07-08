
#include "magnet_integration.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "common.h"

// Max command length for MAGNET
#define MAX_CMD_LEN 4096


int IsMagnetAvailable(void) {
    FILE *fp;
    char path[1024];

    // First check if ./MAGNET exists and is executable
    if (access("./MAGNET", X_OK) == 0) {
        return 1;
    }

    // Then check if MAGNET is in the system path
    fp = popen("which MAGNET", "r");
    if (fp == NULL) return 0;

    int found = (fgets(path, sizeof(path), fp) != NULL);
    pclose(fp);

    return found;
}

void PrintMagnetVersion(void) {
    FILE *fp;
    char buffer[1024];

    // Prefer ./MAGNET if available, fallback to system MAGNET
    const char *cmd = (access("./MAGNET", X_OK) == 0) ? "./MAGNET -V" : "MAGNET -V";

    fp = popen(cmd, "r");
    if (fp == NULL) {
        fprintf(stderr, "Error: Failed to run MAGNET version check.\n");
        return;
    }

    fprintf(stderr, "==[ MAGNET INFORMATION ]===========               \n");
    while (fgets(buffer, sizeof(buffer), fp) != NULL) {
        fprintf(stderr, "%s", buffer);
    }
    fprintf(stderr, "\n");

    pclose(fp);
}

FILE *RunMagnetPipe(const char *inputReads, const char *filterReference,
    double threshold, U32 level, U8 invert, U8 verbose,
    U32 portion, U32 nThreads) {
    char command[MAX_CMD_LEN];
    char threadStr[16] = ""; // Buffer for thread parameter
    FILE *magnetOutput;

    // Check if MAGNET is available
    if (!IsMagnetAvailable()) {
        fprintf(stderr, "Error: MAGNET tool not found in system path.\n");
        fprintf(stderr, "Please install MAGNET or add it to your PATH.\n");
        return NULL;
    }

    // Check input files existence
    if (inputReads == NULL || access(inputReads, F_OK) != 0) {
        fprintf(stderr, "Error: Input file not found: %s\n", 
                inputReads ? inputReads : "NULL");
        return NULL;
    }

    if (filterReference == NULL || access(filterReference, F_OK) != 0) {
        fprintf(stderr, "Error: Filter reference file not found: %s\n", 
                filterReference ? filterReference : "NULL");
        return NULL;
    }

    // Prepare thread parameter if needed
    if (nThreads > 0) {
        snprintf(threadStr, sizeof(threadStr), "-n %d ", nThreads);
    }
    
    const char *magnetBin = (access("./MAGNET", X_OK) == 0) ? "./MAGNET" : "MAGNET";

    // Build command with thread count if specified
    snprintf(command, MAX_CMD_LEN,
        "%s %s%s -F -l %d -t %.6f -p %d %s%s %s",
        magnetBin,
        verbose ? "-v " : "",
        invert ? "-i " : "",
        level,
        threshold,
        portion,
        threadStr,
        filterReference,
        inputReads);


    // Show command in verbose mode
    if (verbose) {
        fprintf(stderr, "      [+] Running MAGNET filter: %s\n", command);
    } else {
        fprintf(stderr, "      [+] Running MAGNET filter...\n");
    }

    // Execute MAGNET with popen to get a FILE* to its output
    magnetOutput = popen(command, "r");
    if (magnetOutput == NULL) {
        fprintf(stderr, "Error: Failed to execute MAGNET command.\n");
        return NULL;
    }
    // Return the pipe - caller must use pclose() when done
    return magnetOutput;
}

int RunMagnet(const char *inputReads, const char *filterReference,
    double threshold, U32 level, U8 invert, U8 verbose,
    U32 portion, const char *outputFile, U32 nThreads) {

    char command[MAX_CMD_LEN];
    char threadStr[16] = ""; // Buffer for thread parameter
    int result;
    char *readsPath = NULL, *refPath = NULL;

    // Check if MAGNET is available
    if (!IsMagnetAvailable()) {
        fprintf(stderr, "Error: MAGNET tool not found in system path.\n"
                        "Please install MAGNET or add it to your PATH.\n");
        return -1;
    }

    // Validate required parameters
    if (outputFile == NULL) {
        fprintf(stderr, "Error: Output file must be specified for RunMagnet\n");
        return -1;
    }
    
    // Check input files existence
    if (inputReads == NULL || access(inputReads, F_OK) != 0) {
        fprintf(stderr, "Error: Input file not found: %s\n", 
                inputReads ? inputReads : "NULL");
        return -2;
    }

    // Prepare reads file
    if (ends_with(inputReads, ".gz"))
        readsPath = decompressToTemp(inputReads);
    else
        readsPath = strdup(inputReads);

    if (filterReference == NULL || access(filterReference, F_OK) != 0) {
        fprintf(stderr, "Error: Filter reference file not found: %s\n", 
                filterReference ? filterReference : "NULL");
        return -3;
    }

    if (ends_with(filterReference, ".gz")) {
        refPath = decompressToTemp(filterReference);
        if (!refPath) {
            free(readsPath);
            return -3;
        }
    } else {
        refPath = strdup(filterReference);
    }

    // Prepare thread parameter if needed
    if (nThreads > 0) {
        snprintf(threadStr, sizeof(threadStr), "-n %d ", nThreads);
    }

    // Check if we can use a local MAGNET binary, otherwise use from PATH
    const char *magnetBin = (access("./MAGNET", X_OK) == 0) ? "./MAGNET" : "MAGNET";

    // Construct MAGNET command with output file
    snprintf(command, MAX_CMD_LEN,
        "%s %s%s -F -l %d -t %.6f -p %d %s-o %s %s %s",
        magnetBin,
        verbose ? "-v " : "",
        invert ? "-i " : "",
        level,
        threshold,
        portion,
        threadStr,
        outputFile,
        refPath,
        readsPath);

    // Show command in verbose mode
    if (verbose) {
        fprintf(stderr, "      [+] Running MAGNET filter: %s\n", command);
    } else {
        fprintf(stderr, "      [+] Running MAGNET filter...\n");
    }

    // Execute MAGNET as a system command
    result = system(command);
    if (result != 0) {
        fprintf(stderr, "Error: MAGNET filtering failed with code %d.\n", result);
        return -4;
    }

    // Cleanup
    if (readsPath) unlink(readsPath), free(readsPath);
    if (refPath)   unlink(refPath),   free(refPath);

   // Verify that output file was created
    if (access(outputFile, F_OK) != 0) {
        fprintf(stderr, "Error: MAGNET did not create output file: %s\n", outputFile);
        return -5;
    }

    return 0;
}