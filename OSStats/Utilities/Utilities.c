//
//  Utilities.c
//  OSStats
//

#include "Utilities.h"
#include "smc.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

OsStats * os_stats(void) {
    return os_stats_exclude_pid(0);
}

OsStats* os_stats_exclude_pid(int pid_num) {
    FILE *f;
    int line_len = 1000;
    char line[line_len];

    f = popen("$(which ps) -Ao %cpu,pid,comm", "r");
    if (f == NULL) {
        return NULL;
    }

    int counter = 0;
    double max_cpu_consume = 0.0;
    int pid_val = 0;
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

            while (*string == empty) {
                string++;
            }
            char pid[10];
            memset(pid, '\0', 10);

            index = 0;
            while (*string != empty) {
                pid[index] = *string;
                index++;
                string++;
            }

            int pid_tmp = atoi(pid);

            double cpu_consume = atof(cpu);
            if (cpu_consume > max_cpu_consume && pid_num != pid_tmp) {
                max_cpu_consume = cpu_consume;
                pid_val = pid_tmp;

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
        stats->max_consume_proc_raw_value = max_cpu_consume;
        stats->pid = pid_val;

        SMCOpen();
        stats->cpu_temperature = readCpuTemp();
        SMCClose();

        return stats;
    }

    return NULL;
}

void kill9(int pid) {
    if (pid <= 0) {
        return;
    }
    int len = 40;
    char command[len];
    memset(command, '\0', len);
    sprintf(command, "/bin/kill -9 %i", pid);
    system(command);
}

void os_stats_free(OsStats *stats) {
    if (stats == NULL) { return; }
    if (stats->max_consume_proc_name != NULL) {
        free(stats->max_consume_proc_name);
        stats->max_consume_proc_name = NULL;
    }
    if (stats->max_consume_proc_value != NULL) {
        free(stats->max_consume_proc_value);
        stats->max_consume_proc_value = NULL;
    }
    free(stats);
    stats = NULL;
}

OsMemStats os_mem_stats(void) {
    OsMemStats stats = { 0, 0 };
    return stats;
}
