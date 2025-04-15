/**
 * @file file_compression.h
 * @brief Header file for compressed file I/O operations
 * 
 * This module provides functions to handle reading from both regular and 
 * compressed files (gzip) using a unified interface.
 */

#ifndef FILE_COMPRESSION_H
#define FILE_COMPRESSION_H
#include <stdio.h>

#endif //FILE_COMPRESSION_H

/**
 * @brief Opens a file, automatically detecting compression format
 * 
 * @param filename Path to the file
 * @param mode File opening mode ("r", "w", etc.)
 * @return File* Pointer to the opened file
 */
FILE *CFopen(const char *filename, const char *mode);