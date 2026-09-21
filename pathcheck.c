#include <errno.h>
#include <limits.h>
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

/* Returns allocated storage owned by the caller. */
static char *join_path(const char *dir, size_t dir_len, const char *program)
{
    size_t prog_len;
    size_t need_slash;
    size_t total;
    char *result;

    prog_len = strlen(program);
    need_slash = (dir_len > 0 && dir[dir_len - 1] == '/') ? 0U : 1U;

    /* Check each addition before performing it, including the terminator. */
    if (prog_len > (size_t)-1 - need_slash - 1U)
        return NULL;
    total = prog_len + need_slash + 1U;
    if (dir_len > (size_t)-1 - total)
        return NULL;
    total += dir_len;
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

/*
 * Rescan borrowed PATH slices to find the first exact-text duplicate.
 * No entry storage is retained; PATH remains alive and unchanged in main.
 */
static unsigned long first_occurrence(const char *path, const char *start,
                                      size_t length)
{
    const char *entry;
    const char *end;
    unsigned long number;

    entry = path;
    number = 1;
    while (entry < start) {
        end = entry;
        while (*end != ':' && *end != '\0')
            end++;
        if ((size_t)(end - entry) == length &&
            memcmp(entry, start, length) == 0)
            return number;
        entry = end + 1;
        number++;
    }
    return 0;
}

/* Borrows a terminated directory name; warnings are not runtime errors. */
static int inspect_directory(const char *directory, unsigned long number)
{
    struct stat st;
    int saved_errno;

    if (stat(directory, &st) != 0) {
        saved_errno = errno;
        if (saved_errno == ENOENT) {
            printf("      warning: PATH[%lu] directory missing\n", number);
            return 0;
        }
        if (saved_errno == ENOTDIR) {
            printf("      warning: PATH[%lu] non-directory path component\n",
                   number);
            return 0;
        }
        fprintf(stderr, "pathcheck: PATH[%lu] %s: stat: %s\n",
                number, directory, strerror(saved_errno));
        return -1;
    }
    if (!S_ISDIR(st.st_mode)) {
        printf("      warning: PATH[%lu] not a directory\n", number);
        return 0;
    }
    if ((st.st_mode & S_IWOTH) != 0) {
        /* POSIX sticky-bit value; S_ISVTX may be hidden in strict C89 mode. */
        printf("      warning: PATH[%lu] world-writable directory "
               "(sticky bit %s)\n", number,
               (st.st_mode & 01000) != 0 ? "set" : "not set");
    }
    return 0;
}

/* Borrows candidate; returns 1 for a match, 0 for a miss, -1 on error. */
static int inspect_candidate(const char *candidate)
{
    struct stat st;
    int saved_errno;

    if (stat(candidate, &st) != 0) {
        saved_errno = errno;
        if (saved_errno == ENOENT || saved_errno == ENOTDIR) {
            printf("  %-40s not found\n", candidate);
            return 0;
        }
        printf("  %-40s inspection failed\n", candidate);
        fprintf(stderr, "pathcheck: %s: stat: %s\n",
                candidate, strerror(saved_errno));
        return -1;
    }

    if (S_ISDIR(st.st_mode)) {
        printf("  %-40s directory\n", candidate);
        return 0;
    }

    if (!S_ISREG(st.st_mode)) {
        printf("  %-40s not a regular file\n", candidate);
        return 0;
    }

    if (access(candidate, X_OK) == 0) {
        printf("  %-40s executable\n", candidate);
        return 1;
    }

    saved_errno = errno;
    if (saved_errno == EACCES) {
        printf("  %-40s exists, not executable\n", candidate);
        return 0;
    }
    if (saved_errno == ENOENT || saved_errno == ENOTDIR) {
        printf("  %-40s not found\n", candidate);
        return 0;
    }
    printf("  %-40s inspection failed\n", candidate);
    fprintf(stderr, "pathcheck: %s: access: %s\n",
            candidate, strerror(saved_errno));
    return -1;
}

int main(int argc, char **argv)
{
    const char *path;
    const char *p;
    const char *start;
    const char *dir_text;
    size_t dir_len;
    char *candidate;
    char *directory;
    unsigned long earlier;
    int found;
    int selected;
    int had_error;
    unsigned long entry_no;

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

    /* Environment storage is borrowed and never modified. */
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
    had_error = 0;
    entry_no = 1;

    for (;;) {
        if (*p == ':' || *p == '\0') {
            dir_len = (size_t)(p - start);
            dir_text = start;
            earlier = first_occurrence(path, start, dir_len);

            if (dir_len == 0U) {
                dir_text = ".";
                dir_len = 1U;
            }

            candidate = join_path(dir_text, dir_len, argv[1]);
            if (candidate == NULL) {
                fprintf(stderr, "pathcheck: cannot allocate candidate path\n");
                return EXIT_NOT_FOUND;
            }

            printf("[%lu] ", entry_no);
            found = inspect_candidate(candidate);

            if (found < 0)
                had_error = 1;

            if (found > 0) {
                if (selected == 0) {
                    printf("      selected\n");
                    selected = 1;
                } else {
                    printf("      shadowed\n");
                }
            }

            if (earlier != 0)
                printf("      warning: PATH[%lu] duplicates PATH[%lu]\n",
                       entry_no, earlier);

            /* Classify the original slice before empty-entry substitution. */
            if (p == start)
                printf("      warning: PATH[%lu] empty entry searches "
                       "current directory\n", entry_no);
            else if (*start != '/')
                printf("      warning: PATH[%lu] relative entry\n", entry_no);

            /* Own this terminated copy only for the directory inspection. */
            directory = (char *)malloc(dir_len + 1U);
            if (directory == NULL) {
                free(candidate);
                fprintf(stderr, "pathcheck: cannot allocate PATH entry\n");
                return EXIT_NOT_FOUND;
            }
            memcpy(directory, dir_text, dir_len);
            directory[dir_len] = '\0';
            if (inspect_directory(directory, entry_no) < 0)
                had_error = 1;
            free(directory);
            free(candidate);
            if (*p == '\0')
                break;

            if (entry_no == ULONG_MAX) {
                fprintf(stderr, "pathcheck: too many PATH entries\n");
                return EXIT_NOT_FOUND;
            }
            entry_no++;
            start = p + 1;
        }

        p++;
    }

    if (had_error != 0) {
        printf("lookup incomplete: inspection errors occurred\n");
        return EXIT_NOT_FOUND;
    }

    if (selected == 0) {
        printf("not found in PATH\n");
        return EXIT_NOT_FOUND;
    }

    return EXIT_FOUND;
}
