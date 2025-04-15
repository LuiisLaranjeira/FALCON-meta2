/**
 * @file /**
 * @file file_compression.c
 * @brief Implementation of compressed file I/O operations
 */

#include "file_compression.h"
#include "mem.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "common.h"

FILE* CFopen(const char* filename, const char* mode) {
    // Check if file has a compression extension (.gz)
    if (ends_with(filename, ".gz")) {
        // Create a command like "gzip -dc filename"
        char cmd[1024];
        sprintf(cmd, "gzip -dc %s", filename);
        
        // Open a pipe to the command
        FILE* f = popen(cmd, "r");
        if (!f) {
            fprintf(stderr, "Error opening compressed file: %s\n", filename);
            exit(1);
        }
        return f;
    }
    
    // For uncompressed files, use regular Fopen
    return Fopen(filename, mode);
}
