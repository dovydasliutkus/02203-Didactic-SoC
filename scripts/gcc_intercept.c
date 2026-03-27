#define _GNU_SOURCE
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>

static char *replace_gcc(const char *cmd) {
    const char *old_gcc = "/opt/intelFPGA/questa_fse/questa_fse/gcc-10.3.0-linux_x86_64/bin/gcc";
    const char *new_gcc = "/usr/bin/gcc";
    char *pos = strstr(cmd, old_gcc);
    if (!pos) return NULL;
    size_t old_len = strlen(old_gcc);
    size_t new_len = strlen(new_gcc);
    size_t cmd_len = strlen(cmd);
    char *new_cmd = malloc(cmd_len - old_len + new_len + 1);
    size_t prefix_len = pos - cmd;
    memcpy(new_cmd, cmd, prefix_len);
    memcpy(new_cmd + prefix_len, new_gcc, new_len);
    strcpy(new_cmd + prefix_len + new_len, pos + old_len);
    return new_cmd;
}

int system(const char *cmd) {
    static int (*real_system)(const char *) = NULL;
    if (!real_system) real_system = dlsym(RTLD_NEXT, "system");
    char *new_cmd = replace_gcc(cmd);
    int ret = real_system(new_cmd ? new_cmd : cmd);
    free(new_cmd);
    return ret;
}
