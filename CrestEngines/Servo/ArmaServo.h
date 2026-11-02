#include <stdint.h>
typedef struct ArmaServoEngine ArmaServoEngine;
typedef struct ArmaServoPage ArmaServoPage;
typedef void (*ArmaWake)(void *context);
typedef void (*ArmaFrame)(void *page_context);
typedef void (*ArmaEvent)(void *page_context, int32_t kind, const char *text);
enum { ARMA_EVENT_TITLE = 0, ARMA_EVENT_URL = 1, ARMA_EVENT_LOAD_STARTED = 2, ARMA_EVENT_LOAD_COMPLETE = 3,
    ARMA_EVENT_HISTORY = 4 /* index, then each entry URL, one per line */, ARMA_EVENT_LOAD_HEAD_PARSED = 5 };
enum { ARMA_MODIFIER_SHIFT = 1, ARMA_MODIFIER_CONTROL = 2, ARMA_MODIFIER_ALT = 4, ARMA_MODIFIER_META = 8 };
ArmaServoEngine *arma_servo_engine_new(const char *profile_dir, void *context, ArmaWake wake);
void arma_servo_engine_spin(ArmaServoEngine *engine);
void arma_servo_engine_free(ArmaServoEngine *engine);
int32_t arma_servo_engine_cookie_count(ArmaServoEngine *engine, const char *url);
void arma_servo_engine_clear_cookies(ArmaServoEngine *engine);
void arma_servo_engine_add_user_script(ArmaServoEngine *engine, const char *script);
ArmaServoPage *arma_servo_page_new(ArmaServoEngine *engine, void *ns_view, uint32_t width, uint32_t height, float scale,
    const char *url, void *page_context, ArmaFrame frame, ArmaEvent event);
void arma_servo_page_free(ArmaServoPage *page);
void arma_servo_page_paint(ArmaServoPage *page);
void arma_servo_page_resize(ArmaServoPage *page, uint32_t width, uint32_t height);
void arma_servo_page_set_visible(ArmaServoPage *page, int32_t visible);
void arma_servo_page_set_focused(ArmaServoPage *page, int32_t focused);
void arma_servo_page_load(ArmaServoPage *page, const char *url);
void arma_servo_page_traverse(ArmaServoPage *page, int32_t steps);
void arma_servo_page_reload(ArmaServoPage *page);
void arma_servo_page_scroll(ArmaServoPage *page, double dx, double dy, float x, float y);
void arma_servo_page_mouse_button(ArmaServoPage *page, int32_t button, int32_t down, float x, float y);
void arma_servo_page_mouse_move(ArmaServoPage *page, float x, float y);
void arma_servo_page_key(ArmaServoPage *page, int32_t down, const char *key, uint32_t modifiers);
