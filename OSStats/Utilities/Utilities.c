//
//  Utilities.c
//  OSStats
//

#include "Utilities.h"
#include "smc.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

OsStats* os_stats(void) {
    FILE *f;
    int line_len = 1000;
    char line[line_len];

    f = popen("$(which ps) -Ao %cpu,comm", "r");
    if (f == NULL) {
        return NULL;
    }

    int counter = 0;
    double max_spu_consume = 0.0;
    char *process_name = NULL;
    char *process_consume = NULL;
    while (fgets(line, line_len, f) != NULL) {
        if (strlen(line) > 0 && counter > 0) {
            char *string = malloc((strlen(line) + 1) * sizeof(char));
            strcpy(string, line);
            char *start = string;
            char empty = ' ';
            while (*string == empty) {
                string++;
            }
            char cpu[10];
            memset(cpu, '\0', 10);

            int index = 0;
            while (*string != empty) {
                cpu[index] = *string;
                index++;
                string++;
            }

            double cpu_consume = atof(cpu);
            if (cpu_consume > max_spu_consume) {
                max_spu_consume = cpu_consume;

                char *p = strrchr(string, '/');
                if (process_name != NULL) {
                    free(process_name);
                }
                if (process_consume != NULL) {
                    free(process_consume);
                }
                if (p != NULL) {
                    p++;
                    process_name = malloc((strlen(p) + 1) * sizeof(char));
                    strcpy(process_name, p);
                } else {
                    string++;
                    process_name = malloc((strlen(string) + 1) * sizeof(char));
                    strcpy(process_name, string);
                }
                process_consume = malloc((strlen(cpu) + 1) * sizeof(char));
                strcpy(process_consume, cpu);
            }

            string = start;
            free(string);
        }
        counter++;
    }

    pclose(f);

    if (process_consume != NULL && process_name != NULL) {
        OsStats *stats = malloc(sizeof(OsStats));
        stats->max_consume_proc_name = process_name;
        stats->max_consume_proc_value = process_consume;

        SMCOpen();
        stats->cpu_temperature = readCpuTemp();
        SMCClose();

        return stats;
    }

    return NULL;
}

void os_stats_free(OsStats *stats) {
    if (stats == NULL) { return; }
    if (stats->max_consume_proc_name != NULL) {
        free(stats->max_consume_proc_name);
    }
    if (stats->max_consume_proc_value != NULL) {
        free(stats->max_consume_proc_value);
    }
    free(stats);
}
