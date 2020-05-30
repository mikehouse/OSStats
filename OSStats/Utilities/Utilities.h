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
    double cpu_temperature;
} OsStats;

OsStats * os_stats(void);
void os_stats_free(OsStats *);

#endif /* Utilities_h */
