//
//  Utilities.h
//  OSStats
//

#ifndef Utilities_h
#define Utilities_h

#include <stdio.h>

typedef struct os_stats_t {
    char *max_consume_proc_name; // "Xcode"
    char *max_consume_proc_value; // "91.1"
    double max_consume_proc_raw_value; // 91.1
    double cpu_temperature;
    int pid;
} OsStats;

typedef struct os_mem_stats_t {
    long long free_bytes;
    long long used_bytes;
} OsMemStats;

OsStats * os_stats(void);
OsStats * os_stats_exclude_pid(int);
void os_stats_free(OsStats *);

void kill9(int pid);

OsMemStats os_mem_stats(void);

#endif /* Utilities_h */
