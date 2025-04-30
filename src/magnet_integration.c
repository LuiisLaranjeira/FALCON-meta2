
#include "magnet_integration.h"

#include <stdio.h>
#include <stdlib.h>

// Max command length for MAGNET
#define MAX_CMD_LEN 4096


MagnetParams CreateMagnetParams(void) {
    MagnetParams params;
    
    // Initialize with default values
    params.inputReads = NULL;
    params.filterReference = NULL;
    params.outputFile = NULL;
    params.threshold = 0.9;
    params.level = 36;
    params.portion = 1;
    params.invert = 0;
    params.verbose = 0;
    params.nThreads = 2;
    
    return params;
}


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

FILE *RunMagnetPipe(const MagnetParams *params) {
    char command[MAX_CMD_LEN];
    FILE *magnetOutput;

    // Check if MAGNET is available
    if (!IsMagnetAvailable()) {
        fprintf(stderr, "Error: MAGNET tool not found in system path.\n");
        fprintf(stderr, "Please install MAGNET or add it to your PATH.\n");
        return NULL;
    }

    // Check input files existence
    if (params->inputReads == NULL || access(params->inputReads, F_OK) != 0) {
        fprintf(stderr, "Error: Input FASTQ file not found: %s\n", 
                params->inputReads ? params->inputReads : "NULL");
        return NULL;
    }

    if (params->filterReference == NULL || access(params->filterReference, F_OK) != 0) {
        fprintf(stderr, "Error: Filter reference file not found: %s\n", 
                params->filterReference ? params->filterReference : "NULL");
        return NULL;
    }

    const char *magnetBin = (access("./MAGNET", X_OK) == 0) ? "./MAGNET" : "MAGNET";

        // Build command with thread count if specified
    snprintf(command, MAX_CMD_LEN,
             "%s %s%s -F -l %d -t %.6f -p %d %s%s %s %s",
             magnetBin,
             params->verbose ? "-v " : "",
             params->invert ? "-i " : "",
             params->level,
             params->threshold,
             params->portion,
             (params->nThreads > 0) ? "-n " : "",
             (params->nThreads > 0) ? (char[]){params->nThreads + '0', ' ', '\0'} : "",
             params->filterReference,
             params->inputReads);


    // Show command in verbose mode
    if (params->verbose) {
        fprintf(stderr, "  [+] Running MAGNET filter: %s\n", command);
    } else {
        fprintf(stderr, "  [+] Running MAGNET filter...\n");
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

int RunMagnet(const MagnetParams *params) {
    char command[MAX_CMD_LEN];
    int result;

    // Check if MAGNET is available
    if (!IsMagnetAvailable()) {
        fprintf(stderr, "Error: MAGNET tool not found in system path.\n");
        fprintf(stderr, "Please install MAGNET or add it to your PATH.\n");
        return -1;
    }

    // Validate required parameters
    if (params->outputFile == NULL) {
        fprintf(stderr, "Error: Output file must be specified for RunMagnet\n");
        return -1;
    }
    
    // Check input files existence
    if (params->inputReads == NULL || access(params->inputReads, F_OK) != 0) {
        fprintf(stderr, "Error: Input file not found: %s\n", 
                params->inputReads ? params->inputReads : "NULL");
        return -2;
    }

    if (params->filterReference == NULL || access(params->filterReference, F_OK) != 0) {
        fprintf(stderr, "Error: Filter reference file not found: %s\n", 
                params->filterReference ? params->filterReference : "NULL");
        return -3;
    }

    // Check if we can use a local MAGNET binary, otherwise use from PATH
    const char *magnetBin = (access("./MAGNET", X_OK) == 0) ? "./MAGNET" : "MAGNET";

    // Construct MAGNET command with output file and thread count if specified
    snprintf(command, MAX_CMD_LEN,
             "%s %s%s -F -l %d -t %.6f -p %d %s%s -o %s %s %s",
             magnetBin,
             params->verbose ? "-v " : "",
             params->invert ? "-i " : "",
             params->level,
             params->threshold,
             params->portion,
             (params->nThreads > 0) ? "-n " : "",
             (params->nThreads > 0) ? (char[]){params->nThreads + '0', ' ', '\0'} : "",
             params->outputFile,
             params->filterReference,
             params->inputReads);

    // Show command in verbose mode
    if (params->verbose) {
        fprintf(stderr, "  [+] Running MAGNET filter: %s\n", command);
    } else {
        fprintf(stderr, "  [+] Running MAGNET filter...\n");
    }

    // Execute MAGNET as a system command
    result = system(command);
    if (result != 0) {
        fprintf(stderr, "Error: MAGNET filtering failed with code %d.\n", result);
        return -4;
    }

   // Verify that output file was created
    if (access(params->outputFile, F_OK) != 0) {
        fprintf(stderr, "Error: MAGNET did not create output file: %s\n", params->outputFile);
        return -5;
    }

    return 0;
}