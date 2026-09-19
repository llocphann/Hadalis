// Development-only compositor input for an explicit isolated Wayland socket.
// No default display fallback: never inject events into the desktop by accident.
#include <wayland-client.h>
#include <linux/input-event-codes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include "pointer-client.h"

static struct zwlr_virtual_pointer_manager_v1 *manager;
static void global(void *data, struct wl_registry *registry, uint32_t name,
                   const char *interface, uint32_t version) {
    (void)data;
    if (!strcmp(interface, "zwlr_virtual_pointer_manager_v1"))
        manager = wl_registry_bind(registry, name,
            &zwlr_virtual_pointer_manager_v1_interface, version < 2 ? version : 2);
}
static void removed(void *data, struct wl_registry *registry, uint32_t name) {
    (void)data; (void)registry; (void)name;
}
static const struct wl_registry_listener listener = {global, removed};
static uint32_t now(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (uint32_t)(t.tv_sec * 1000 + t.tv_nsec / 1000000);
}
static void send_input(struct wl_display *display, struct zwlr_virtual_pointer_v1 *pointer,
                       unsigned x, unsigned y, unsigned width, unsigned height, const char *action) {
    zwlr_virtual_pointer_v1_motion_absolute(pointer, now(), x, y, width, height);
    zwlr_virtual_pointer_v1_frame(pointer);
    wl_display_roundtrip(display);
    usleep(120000);
    if (strcmp(action,"move")) {
        uint32_t button = !strcmp(action,"right") ? BTN_RIGHT : BTN_LEFT;
        zwlr_virtual_pointer_v1_button(pointer,now(),button,WL_POINTER_BUTTON_STATE_PRESSED);
        zwlr_virtual_pointer_v1_frame(pointer);
        wl_display_roundtrip(display);
        usleep(60000);
        zwlr_virtual_pointer_v1_button(pointer,now(),button,WL_POINTER_BUTTON_STATE_RELEASED);
        zwlr_virtual_pointer_v1_frame(pointer);
        wl_display_roundtrip(display);
        usleep(60000);
    }
}
int main(int argc, char **argv) {
    if ((argc != 2 && argc != 7) || argv[1][0] != '/') {
        fprintf(stderr, "usage: pointer /absolute/isolated/socket [x y width height move|left|right]\n");
        return 2;
    }
    struct wl_display *display = wl_display_connect(argv[1]);
    if (!display) { perror("wl_display_connect"); return 3; }
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &listener, NULL);
    wl_display_roundtrip(display);
    if (!manager) { fprintf(stderr,"virtual-pointer protocol absent\n"); return 4; }
    struct zwlr_virtual_pointer_v1 *pointer =
        zwlr_virtual_pointer_manager_v1_create_virtual_pointer(manager, NULL);
    if (argc == 7) {
        send_input(display,pointer,strtoul(argv[2],NULL,10),strtoul(argv[3],NULL,10),
                   strtoul(argv[4],NULL,10),strtoul(argv[5],NULL,10),argv[6]);
    } else {
        // Keep the seat device alive: removing the last headless pointer emits
        // leave and makes an auto-hide experiment measure device removal instead.
        unsigned x,y,width,height;
        char action[16];
        while (scanf("%u %u %u %u %15s",&x,&y,&width,&height,action)==5) {
            if (!width || !height || (strcmp(action,"move") && strcmp(action,"left") && strcmp(action,"right"))) return 5;
            send_input(display,pointer,x,y,width,height,action);
            puts("ok"); fflush(stdout);
        }
    }
    zwlr_virtual_pointer_v1_destroy(pointer);
    zwlr_virtual_pointer_manager_v1_destroy(manager);
    wl_registry_destroy(registry);
    wl_display_flush(display);
    wl_display_disconnect(display);
    return 0;
}
