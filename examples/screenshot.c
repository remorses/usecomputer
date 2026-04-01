// Simple example: call usecomputer C API functions.
// Build and run with: pnpm example:c

#include <stdio.h>
#include <stdlib.h>
#include "usecomputer.h"

int main(void) {
    // -- Mouse position (no special permissions needed) --
    double mx, my;
    if (uc_mouse_position(&mx, &my) == 0) {
        printf("Mouse position: %.0f, %.0f\n", mx, my);
    } else {
        fprintf(stderr, "mouse_position failed: %s\n", uc_last_error());
    }

    // -- Display list --
    char* displays = uc_display_list();
    if (displays) {
        printf("Displays: %s\n", displays);
        uc_free(displays);
    } else {
        fprintf(stderr, "display_list failed: %s\n", uc_last_error());
    }

    // -- Screenshot (requires Screen Recording permission on macOS) --
    printf("Taking screenshot...\n");
    char* result = uc_screenshot("./tmp/c-api-test.png", -1, -1);
    if (!result) {
        fprintf(stderr, "screenshot failed: %s\n", uc_last_error());
        fprintf(stderr, "(grant Screen Recording permission to run this)\n");
        return 0;
    }

    printf("Screenshot result:\n%s\n", result);
    uc_free(result);
    return 0;
}
