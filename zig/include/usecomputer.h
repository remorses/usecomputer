/* usecomputer C API — desktop automation for AI agents.
 *
 * All uc_* command functions return 0 on success, -1 on error.
 * Call uc_last_error() after a failure to get the error message.
 *
 * Functions returning char* allocate memory that the caller must
 * free with uc_free(). They return NULL on error.
 *
 * Pointer parameters marked "must not be NULL" will return -1 with
 * an error message if NULL is passed.
 */

#ifndef USECOMPUTER_H
#define USECOMPUTER_H

#ifdef __cplusplus
extern "C" {
#endif

/* ── Error handling ── */

/* Returns the last error message (library-owned, do not free).
 * Valid until the next uc_* call on this thread. Returns NULL if no error. */
const char* uc_last_error(void);

/* Free a string returned by uc_screenshot, uc_display_list, or uc_window_list.
 * Accepts NULL (no-op). */
void uc_free(void* ptr);

/* ── Screenshot ── */

/* Capture a screenshot. Returns a JSON string with path, dimensions, and
 * coord-map data. Caller must uc_free() the result. Returns NULL on error.
 * path: output file path, or NULL for default ("./screenshot.png").
 * display: display index (0-based), or -1 for default.
 * window: window ID, or -1 for full-screen capture. */
char* uc_screenshot(const char* path, int display, int window);

/* ── Mouse ── */

/* button values: 0 = left, 1 = right, 2 = middle */

int uc_click(double x, double y, int button, int count);
int uc_mouse_move(double x, double y);
int uc_mouse_down(int button);
int uc_mouse_up(int button);
int uc_hover(double x, double y);

/* Drag from (from_x, from_y) to (to_x, to_y).
 * If has_cp is non-zero, (cp_x, cp_y) is a quadratic bezier control point. */
int uc_drag(double from_x, double from_y, double to_x, double to_y,
            double cp_x, double cp_y, int has_cp, int button);

/* Write current mouse position into *out_x and *out_y.
 * out_x and out_y must not be NULL. */
int uc_mouse_position(double* out_x, double* out_y);

/* ── Keyboard ── */

/* Type text. text must not be NULL.
 * delay_ms: per-character delay in ms, or -1 for default. */
int uc_type_text(const char* text, int delay_ms);

/* Press a key or chord (e.g. "enter", "cmd+s"). key must not be NULL.
 * count: repeat count. delay_ms: delay between repeats in ms, or -1 for default. */
int uc_press(const char* key, int count, int delay_ms);

/* Press and hold a key (or chord) without releasing. key must not be NULL. */
int uc_key_down(const char* key);

/* Release a held key (or chord). key must not be NULL. */
int uc_key_up(const char* key);

/* ── Scroll ── */

/* direction must not be NULL: "up", "down", "left", "right".
 * If has_at is non-zero, scroll at position (at_x, at_y). */
int uc_scroll(const char* direction, int amount,
              double at_x, double at_y, int has_at);

/* ── Queries ── */

/* Returns a JSON array of display info objects. Caller must uc_free(). */
char* uc_display_list(void);

/* Returns a JSON array of window info objects. Caller must uc_free(). */
char* uc_window_list(void);

#ifdef __cplusplus
}
#endif

#endif /* USECOMPUTER_H */
