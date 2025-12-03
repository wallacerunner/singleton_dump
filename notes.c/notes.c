#include <string.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <dirent.h>


typedef struct date_result {
    char is_today;
} date_result;

const int UTF_BIT_PATTERN = 0xC0; // 0b11000000



void send_notification (char * title, char * content) {
    char cmd[256] = {0};
    snprintf(cmd, sizeof(cmd), "notify-send '%s' '%s'", title, content);
    system(cmd);
}


date_result parse_date (char * date, int byte_length, date_result * dr) {
    // if (dr == NULL) date_result *dr = malloc(sizeof(*dr));
    int year = 0;
    char month, day = 0;

    time_t t = time(NULL);
    struct tm now = *localtime(&t);

    year = (date[0] - 48) * 1000
            + (date[1] - 48) * 100
            + (date[2] - 48) * 10
            + (date[3] - 48);
    month = (date[5] - 48) * 10
            + (date[6] - 48);
    day = (date[8] - 48) * 10
            + (date[9] - 48);

    if (year == (now.tm_year + 1900)
        && month == (now.tm_mon + 1)
        && day == now.tm_mday) {
            dr->is_today = 1;
        }

    return *dr;
}


void process_line (char * line, int byte_length) {
    char date_string[17]; // xxxx-xx-xx xx:xx
    date_result d;
    for (int i = 0; i < byte_length; i ++) {
        if ((line[i] & UTF_BIT_PATTERN) == UTF_BIT_PATTERN) {
            // printf("(%#x-%#x) ", line[i], line[i + 1]);
            i ++;
        } else {
            // printf("%#x ", line[i]);
        }
        if (line[i] == '[') {
            i ++;

            // get date part of the line
            int start = i;
            while (line[i] != ']' && i < byte_length) {
                date_string[i - start] = line[i];
                i ++;
            }

            // terminate it
            date_string[i - start] = '\0';
            parse_date (date_string, (i - start), &d);

            // rewind back to first date char for debug reasons
            i = start - 1;
        }
    }
    if (d.is_today > 0) {
        // printf("\nline is due today\n");
        send_notification(line, "");
    }
    // printf("\n");
}


void process_file (FILE * notes_file) {
    int bytes_read = 0;
    char * line = NULL;
    size_t len = 0;
    while ((bytes_read = getline(&line, &len, notes_file)) != -1) {
        if (line[0] != '\n' || line[0] != '\0') {
            // printf("bytes: %i, length: %lu line:\n", bytes_read, len);
            // fwrite(line, bytes_read, 1, stdout);
            process_line(line, bytes_read);
        }
    }
}


char is_notes_file (char * file_name) {
    const char * file_types[] = {"org", "txt"};
    int successes[] = {2, 2};
    const int fn_size = strlen(file_name);
    char current;
    for (int i = 0; i < fn_size; i ++) {
        current = file_name[fn_size - i];

        if (file_name[fn_size - i] == '.') {
            break;
        }

        for (int t = 0; t < ((sizeof(file_types) / sizeof(file_types[0]))); t ++) {
            if (i < 3 && file_types[t][successes[t]] == current) {
                successes[t] --;
            }
        }
    }

    for (int i = 0; i < (sizeof(successes) /sizeof(successes[0])); i ++) {
        if (successes[i] == 0) return 1;
    }

    return 0;
}



int main (int argc, char * argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Not enough arguments provided\n");
        return 1;
    }
    struct dirent * dir_ent;
    DIR * dir = opendir(argv[1]);
    if (dir == NULL) {
        fprintf(stderr, "Can't open dir %s\n", argv[1]);
        return 1;
    }

    char file_path[1024];

    while ((dir_ent = readdir(dir)) != NULL) {
        if (strcmp(dir_ent->d_name, ".") == 0
            || strcmp(dir_ent->d_name, "..") == 0
            || is_notes_file(dir_ent->d_name) == 0)
            continue;

        sprintf(file_path, "%s/%s", argv[1], dir_ent->d_name);

        printf("file: %s\n", file_path);
        FILE * notes_file = fopen(file_path, "r");
        if (notes_file == NULL) {
            fprintf(stderr, "Can't open file %s\n", file_path);
            return 1;
        }

        process_file(notes_file);

        fclose(notes_file);
    }
    closedir(dir);
    return 0;
}

