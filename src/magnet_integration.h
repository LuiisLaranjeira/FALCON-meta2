
#ifndef MAGNET_INTEGRATION_H
#define MAGNET_INTEGRATION_H

#include "defs.h"
#include <stdio.h>

/**
 * Structure to hold MAGNET parameters
 */
typedef struct {
    const char *inputReads;       // Input file to filter
    const char *filterReference; // Reference file for filtering
    const char *outputFile;      // Output file (NULL for pipe mode)
    double threshold;            // Similarity threshold [0.0-1.0]
    int level;                   // Sensitivity level [1-44]
    int portion;                 // Portion of acceptance
    int invert;                  // Whether to invert filtering
    int verbose;                 // Verbose mode
    int nThreads;                // Force overwrite output
} MagnetParams;

/**
 * Create and initialize a MagnetParams structure with default values
 * 
 * @return Initialized MagnetParams structure
 */
MagnetParams CreateMagnetParams(void);

/**
 * Check if MAGNET is available
 * 
 * @return 1 if MAGNET is available, 0 otherwise
 */
int IsMagnetAvailable(void);

/**
 * Print MAGNET version information to stderr
 */
void PrintMagnetVersion(void);

/**
 * Run MAGNET and get its output as a FILE* stream
 * 
 * This function uses popen to create a pipe to MAGNET's output
 * so FALCON can process it directly without intermediate files.
 * 
 * @param params MagnetParams structure
 * @return FILE* handle to MAGNET's output stream or NULL on error
 */
FILE *RunMagnetPipe(const MagnetParams *params);
/**
 * Run MAGNET to filter sequences and save output to a file
 * 
 * This function runs MAGNET as a system command and redirects output to a file.
 * 
 * @param params MagnetParams structure
 * @return 0 on success, non-zero on error
 */
int RunMagnet(const MagnetParams *params);

#endif //MAGNET_INTEGRATION_H
