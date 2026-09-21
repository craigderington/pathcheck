#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define EXIT_FOUND 0
#define EXIT_NOT_FOUND 1
#define EXIT_USAGE 2

static void usage(const char *progname)
{
    fprintf(stderr, "usage: %s program\n", progname);
}

static char *join_path(const char *dir, size_t dir_len, const char *program)
{
    size_t prog_len;
    size_t need_slash;
    size_t total;
    char *result;

    prog_len = strlen(program);
    need_slash = (dir_len > 0 && dir[dir_len - 1] == '/') ? 0U : 1U;

    if (dir_len > (size_t)-1 - prog_len - need_slash - 1U)
        return NULL;

    total = dir_len + need_slash + prog_len + 1U;
    result = (char *)malloc(total);
    if (result == NULL)
        return NULL;

    if (dir_len > 0)
        memcpy(result, dir, dir_len);

    if (need_slash != 0U)
        result[dir_len] = '/';

    memcpy(result + dir_len + need_slash, program, prog_len);
    result[total - 1U] = '\0';

    return result;
}

static int inspect_candidate(const char *candidate)
{
    struct stat st;

    if (stat(candidate, &st) != 0) {
        printf("  %-40s not found\n", candidate);
        return 0;
    }

    if (S_ISDIR(st.st_mode)) {
        printf("  %-40s directory\n", candidate);
        return 0;
    }

    if (access(candidate, X_OK) == 0) {
        printf("  %-40s executable\n", candidate);
        return 1;
    }

    printf("  %-40s exists, not executable\n", candidate);
    return 0;
}

int main(int argc, char **argv)
{
    const char *path;
    const char *p;
    const char *start;
    const char *dir_text;
    size_t dir_len;
    char *candidate;
    int found;
    int selected;
    int entry_no;

    if (argc != 2) {
        usage(argv[0]);
        return EXIT_USAGE;
    }

    if (argv[1][0] == '\0') {
        fprintf(stderr, "pathcheck: program name must not be empty\n");
        return EXIT_USAGE;
    }

    if (strchr(argv[1], '/') != NULL) {
        fprintf(stderr, "pathcheck: program name must not contain '/'\n");
        return EXIT_USAGE;
    }

    path = getenv("PATH");
    if (path == NULL) {
        fprintf(stderr, "pathcheck: PATH is not set\n");
        return EXIT_NOT_FOUND;
    }

    printf("%s:\n", argv[1]);

    p = path;
    start = path;
    found = 0;
    selected = 0;
    entry_no = 1;

    for (;;) {
        if (*p == ':' || *p == '\0') {
            dir_len = (size_t)(p - start);
            dir_text = start;

            if (dir_len == 0U) {
                dir_text = ".";
                dir_len = 1U;
            }

            candidate = join_path(dir_text, dir_len, argv[1]);
            if (candidate == NULL) {
                fprintf(stderr, "pathcheck: out of memory\n");
                return EXIT_NOT_FOUND;
            }

            printf("[%d] ", entry_no);
            found = inspect_candidate(candidate);

            if (found != 0) {
                if (selected == 0) {
                    printf("      selected\n");
                    selected = 1;
                } else {
                    printf("      shadowed\n");
                }
            }

            free(candidate);
            entry_no++;

            if (*p == '\0')
                break;

            start = p + 1;
        }

        p++;
    }

    if (selected == 0) {
        printf("not found in PATH\n");
        return EXIT_NOT_FOUND;
    }

    return EXIT_FOUND;
}
