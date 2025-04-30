
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "serialization.h"
#include "mem.h"
#include "common.h"

// Helper function to serialize a hashtable to file
static int SerializeHashTable(FILE *F, HashTable *HT) {
  // Write index array
  if(fwrite(HT->index, sizeof(ENTMAX), HASH_SIZE, F) != HASH_SIZE)
    return -1;

  // Write each hash entry
  for(uint32_t i = 0; i < HASH_SIZE; i++) {
    for(uint32_t j = 0; j < HT->maxC; j++) {
      // Write key
      if(fwrite(&HT->entries[i][j].key, sizeof(HT->entries[i][j].key), 1, F) != 1)
        return -1;

      // Write counters
      if(fwrite(&HT->entries[i][j].counters, sizeof(HT->entries[i][j].counters), 1, F) != 1)
        return -1;
    }
  }

  return 0;
}

// Helper function to deserialize a hashtable from file
static int DeserializeHashTable(FILE *F, HashTable *HT, uint32_t col) {
  // Initialize hash table
  HT->maxC = col;
  HT->index = (ENTMAX *) Calloc(HASH_SIZE, sizeof(ENTMAX));
  HT->entries = (Entry **) Calloc(HASH_SIZE, sizeof(Entry *));

  // Read index array
  if(fread(HT->index, sizeof(ENTMAX), HASH_SIZE, F) != HASH_SIZE)
    return -1;

  // Allocate and read each hash entry
  for(uint32_t i = 0; i < HASH_SIZE; i++) {
    HT->entries[i] = (Entry *) Calloc(HT->maxC, sizeof(Entry));

    for(uint32_t j = 0; j < HT->maxC; j++) {
      // Read key
      if(fread(&HT->entries[i][j].key, sizeof(HT->entries[i][j].key), 1, F) != 1)
        return -1;

      // Read counters
      if(fread(&HT->entries[i][j].counters, sizeof(HT->entries[i][j].counters), 1, F) != 1)
        return -1;
    }
  }

  return 0;
}

// Helper function to serialize an array to file
static int SerializeArray(FILE *F, Array *AR, uint64_t nPModels) {
  uint64_t size = nPModels << 2; // * 4 for ACGT
  return fwrite(AR->counters, sizeof(ACC), size, F) != size ? -1 : 0;
}

// Helper function to deserialize an array from file
static int DeserializeArray(FILE *F, Array *AR, uint64_t nPModels) {
  uint64_t size = nPModels << 2; // * 4 for ACGT
  AR->counters = (ACC *) Calloc(size, sizeof(ACC));
  return fread(AR->counters, sizeof(ACC), size, F) != size ? -1 : 0;
}

int SaveModels(const char *filename, CModel **Models, uint32_t nModels, uint32_t col) {
  FILE *F = fopen(filename, "wb");
  if(!F) {
    fprintf(stderr, "Error: Cannot open file %s for writing\n", filename);
    return -1;
  }

  // Write file header
  DBFileHeader header;
  header.magic = MODEL_MAGIC_NUMBER;
  header.version = MODEL_VERSION;
  header.nModels = nModels;
  header.alphabetSize = ALPHABET_SIZE;
  header.timestamp = (uint64_t)time(NULL);
  header.hashSize = HASH_SIZE;
  header.maxCollisions = col;

  if(fwrite(&header, sizeof(DBFileHeader), 1, F) != 1) {
    fprintf(stderr, "Error writing model file header\n");
    fclose(F);
    return -2;
  }

  // For each model
  for(uint32_t n = 0; n < nModels; n++) {
    CModel *M = Models[n];

    // Write model entry header
    ModelMeta entryHeader;
    entryHeader.ctx = M->ctx;
    entryHeader.alphaDen = M->alphaDen;
    entryHeader.ir = M->ir;
    entryHeader.edits = M->edits;
    entryHeader.eDen = M->edits != 0 ? M->SUBS.eDen : 0;
    entryHeader.mode = M->mode;
    entryHeader.nPModels = M->nPModels;
    entryHeader.maxCount = M->maxCount;
    entryHeader.multiplier = M->multiplier;
    entryHeader.dataSize = 0; // Will be calculated based on mode

    if(fwrite(&entryHeader, sizeof(ModelMeta), 1, F) != 1) {
      fprintf(stderr, "Error writing model entry header for model %u\n", n);
      fclose(F);
      return -3;
    }

    // Save model data
    int result = 0;
    switch(M->mode) {
      case HASH_TABLE_MODE:
        result = SerializeHashTable(F, &M->hTable);
        break;
      case ARRAY_MODE:
        result = SerializeArray(F, &M->array, M->nPModels);
        break;
      default:
        fprintf(stderr, "Unknown model mode: %u\n", M->mode);
        fclose(F);
        return -4;
    }

    if(result != 0) {
      fprintf(stderr, "Error serializing model %u data\n", n);
      fclose(F);
      return -5;
    }
  }

  fclose(F);
  return 0;
}

int LoadModels(const char *filename, CModel ***ModelsPtr, uint32_t *nModels, uint32_t *col) {
  FILE *F = fopen(filename, "rb");
  if(!F) {
    fprintf(stderr, "Error: Cannot open file %s for reading\n", filename);
    return -1;
  }

  // Read file header
  DBFileHeader header;
  if(fread(&header, sizeof(DBFileHeader), 1, F) != 1) {
    fprintf(stderr, "Error reading model file header\n");
    fclose(F);
    return -2;
  }

  // Validate header
  if(header.magic != MODEL_MAGIC_NUMBER) {
    fprintf(stderr, "Error: Invalid model file format (wrong magic number)\n");
    fclose(F);
    return -3;
  }

  if(header.version != MODEL_VERSION) {
    fprintf(stderr, "Error: Unsupported model file version: %u\n", header.version);
    fclose(F);
    return -4;
  }

  if(header.alphabetSize != ALPHABET_SIZE) {
    fprintf(stderr, "Error: Model file has different alphabet size: %u (expected %u)\n",
            header.alphabetSize, ALPHABET_SIZE);
    fclose(F);
    return -5;
  }

  // Allocate models
  CModel **Models = (CModel **) Malloc(header.nModels * sizeof(CModel *));
  *nModels = header.nModels;
  *col = header.maxCollisions;

  // For each model
  for(uint32_t n = 0; n < header.nModels; n++) {
    // Read model entry header
    ModelMeta entryHeader;
    if(fread(&entryHeader, sizeof(ModelMeta), 1, F) != 1) {
      fprintf(stderr, "Error reading model entry header for model %u\n", n);
      // Free already loaded models
      for(uint32_t i = 0; i < n; i++)
        FreeCModel(Models[i]);
      Free(Models);
      fclose(F);
      return -6;
    }

    // Create model structure
    Models[n] = (CModel *) Calloc(1, sizeof(CModel));
    CModel *M = Models[n];

    // Fill in basic model parameters
    M->ctx = entryHeader.ctx;
    M->alphaDen = entryHeader.alphaDen;
    M->ir = entryHeader.ir;
    M->edits = entryHeader.edits;
    M->mode = entryHeader.mode;
    M->nPModels = entryHeader.nPModels;
    M->maxCount = entryHeader.maxCount;
    M->multiplier = entryHeader.multiplier;
    M->pModelIdx = 0;
    M->pModelIdxIR = M->nPModels - 1;
    M->ref = 1; // This is a reference model

    // Initialize edits structure if needed
    if(M->edits != 0) {
      M->SUBS.seq = CreateCBuffer(BUFFER_SIZE, BGUARD);
      M->SUBS.in = 0;
      M->SUBS.idx = 0;
      M->SUBS.mask = (uint8_t *) Calloc(BGUARD, sizeof(uint8_t));
      M->SUBS.threshold = M->edits;
      M->SUBS.eDen = entryHeader.eDen;
    }

    // Load model data
    int result = 0;
    switch(M->mode) {
      case HASH_TABLE_MODE:
        result = DeserializeHashTable(F, &M->hTable, header.maxCollisions);
        break;
      case ARRAY_MODE:
        result = DeserializeArray(F, &M->array, M->nPModels);
        break;
      default:
        fprintf(stderr, "Unknown model mode: %u\n", M->mode);
        // Free already loaded models
        for(uint32_t i = 0; i <= n; i++)
          FreeCModel(Models[i]);
        Free(Models);
        fclose(F);
        return -7;
    }

    if(result != 0) {
      fprintf(stderr, "Error deserializing model %u data\n", n);
      // Free already loaded models
      for(uint32_t i = 0; i <= n; i++)
        FreeCModel(Models[i]);
      Free(Models);
      fclose(F);
      return -8;
    }
  }

  *ModelsPtr = Models;
  fclose(F);
  return 0;
}

void FreeLoadedModels(CModel **Models, uint32_t nModels) {
  for(uint32_t n = 0; n < nModels; n++)
    FreeCModel(Models[n]);
  Free(Models);
}

void PrintModelInfo(const char *filename) {
  FILE *F = fopen(filename, "rb");
  if(!F) {
    fprintf(stderr, "Error: Cannot open file %s for reading\n", filename);
    return;
  }

  // Read file header
  DBFileHeader header;
  if(fread(&header, sizeof(DBFileHeader), 1, F) != 1) {
    fprintf(stderr, "Error reading model file header\n");
    fclose(F);
    return;
  }

  // Validate header
  if(header.magic != MODEL_MAGIC_NUMBER) {
    fprintf(stderr, "Error: Invalid model file format (wrong magic number)\n");
    fclose(F);
    return;
  }

  // Print header info
  time_t timestamp = (time_t)header.timestamp;
  char timeStr[100];
  strftime(timeStr, sizeof(timeStr), "%Y-%m-%d %H:%M:%S", localtime(&timestamp));

  fprintf(stderr, "==[ MODEL FILE INFO ]=================\n");
  fprintf(stderr, "Format version ..................... %u\n", header.version);
  fprintf(stderr, "Number of models ................... %u\n", header.nModels);
  fprintf(stderr, "Alphabet size ...................... %u\n", header.alphabetSize);
  fprintf(stderr, "Max hash collisions ................ %u\n", header.maxCollisions);
  fprintf(stderr, "Created on ......................... %s\n", timeStr);
  fprintf(stderr, "\n");

  // Print model info
  fprintf(stderr, "==[ MODELS ]=======================\n");
  for(uint32_t n = 0; n < header.nModels; n++) {
    ModelMeta entryHeader;
    if(fread(&entryHeader, sizeof(ModelMeta), 1, F) != 1) {
      fprintf(stderr, "Error reading model entry header for model %u\n", n);
      fclose(F);
      return;
    }

    fprintf(stderr, "[Model %u]\n", n+1);
    fprintf(stderr, "  [+] Context order ................ %u\n", entryHeader.ctx);
    fprintf(stderr, "  [+] Alpha denominator ............ %u\n", entryHeader.alphaDen);
    fprintf(stderr, "  [+] Inverted repeats ............. %s\n",
           entryHeader.ir == 0 ? "no" : "yes");
    fprintf(stderr, "  [+] Storage mode ................. %s\n",
           entryHeader.mode == ARRAY_MODE ? "array" : "hash table");
    fprintf(stderr, "  [+] Number of models ............. %lu\n", entryHeader.nPModels);

    if(entryHeader.edits != 0) {
      fprintf(stderr, "  [+] Allowable substitutions ...... %u\n", entryHeader.edits);
      fprintf(stderr, "  [+] Substitutions alpha den ...... %u\n", entryHeader.eDen);
    }

    // Skip model data for display purposes
    if(entryHeader.mode == HASH_TABLE_MODE) {
      // Skip index array
      fseek(F, HASH_SIZE * sizeof(ENTMAX), SEEK_CUR);

      // Skip hash entries
      #if defined(PREC32B)
      fseek(F, HASH_SIZE * header.maxCollisions * (sizeof(U32) + sizeof(HCC)), SEEK_CUR);
      #elif defined(PREC16B)
      fseek(F, HASH_SIZE * header.maxCollisions * (sizeof(U16) + sizeof(HCC)), SEEK_CUR);
      #else
      fseek(F, HASH_SIZE * header.maxCollisions * (sizeof(U8) + sizeof(HCC)), SEEK_CUR);
      #endif
    } else if(entryHeader.mode == ARRAY_MODE) {
      // Skip array
      fseek(F, (entryHeader.nPModels << 2) * sizeof(ACC), SEEK_CUR);
    }
  }
  fprintf(stderr, "\n");

  fclose(F);
}