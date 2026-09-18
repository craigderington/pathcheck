#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

enum candidate_kind {
    CANDIDATE_MISSING,
    CANDIDATE_DIRECTORY,
    CANDIDATE_NOT_EXECUTABLE,
    CANDIDATE_EXECUTABLE
};

static char *
make_candidate(const char *directory, size_t directory_length,
               const char *program)
{
    size_t program_length;
    size_t total_length;
    char *candidate;

    program_length = strlen(program);
    if (directory_length > (size_t)-1 - program_length - 2)
        return NULL;

    total_length = directory_length + 1 + program_length + 1;
    candidate = malloc(total_length);
    if (candidate == NULL)
        return NULL;

    if (directory_length == 0) {
        candidate[0] = '.';
        directory_length = 1;
    } else {
        memcpy(candidate, directory, directory_length);
    }

    candidate[directory_length] = '/';
    memcpy(candidate + directory_length + 1, program, program_length + 1);
    return candidate;
}

static enum candidate_kind
inspect_candidate(const char *candidate)
{
    struct stat information;

    if (stat(candidate, &information) != 0)
        return CANDIDATE_MISSING;
    if (S_ISDIR(information.st_mode))
        return CANDIDATE_DIRECTORY;
    if (access(candidate, X_OK) != 0)
        return CANDIDATE_NOT_EXECUTABLE;
    return CANDIDATE_EXECUTABLE;
}

static const char *
kind_name(enum candidate_kind kind, int already_selected)
{
    if (kind == CANDIDATE_DIRECTORY)
        return "is a directory";
    if (kind == CANDIDATE_NOT_EXECUTABLE)
        return "not executable";
    if (kind == CANDIDATE_EXECUTABLE && already_selected)
        return "executable  <-- shadowed";
    if (kind == CANDIDATE_EXECUTABLE)
        return "executable  <-- selected";
    return "not found";
}

int
main(int argc, char **argv)
{
    char *path;
    const char *component;
    const char *separator;
    char *candidate;
    size_t component_length;
    enum candidate_kind kind;
    int selected;
    int position;

    if (argc != 2) {
        fprintf(stderr, "usage: pathcheck program\n");
        return 2;
    }

    path = getenv("PATH");

    if (path == NULL) {
        fprintf(stderr, "pathcheck: PATH is not set\n");
        return 1;
    }

    printf("%s:\n", argv[1]);

    component = path;
    selected = 0;
    position = 1;
    for (;;) {
        separator = strchr(component, ':');
        if (separator == NULL)
            component_length = strlen(component);
        else
            component_length = (size_t)(separator - component);

        candidate = make_candidate(component, component_length, argv[1]);
        if (candidate == NULL) {
            fprintf(stderr, "pathcheck: out of memory\n");
            return 1;
        }

        kind = inspect_candidate(candidate);
        printf("  [%d] %-36s %s\n", position, candidate,
               kind_name(kind, selected));
        if (kind == CANDIDATE_EXECUTABLE)
            selected = 1;
        free(candidate);

        if (separator == NULL)
            break;
        component = separator + 1;
        ++position;
    }

    return selected ? 0 : 1;
}
