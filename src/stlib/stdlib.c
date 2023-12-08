#include <stdio.h>

extern int writestr(char *message) {
    int res = printf("%s", message);
    fflush(stdout);
    return res;
}

extern int writestrnewline(char *message) {
    return puts(message);
}

extern int writeint(long num) {
    int res = printf("%ld", num);
    fflush(stdout); 
    return res;
}
