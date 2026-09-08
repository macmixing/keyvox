#include <android/looper.h>
#include <unistd.h>
#include <stdint.h>
#include <errno.h>

// Swift 6.3.3 libdispatch integration SPI, checked against its pinned source.
// Only this platform adapter depends on these symbols. The host never owns the fd.
extern int _dispatch_get_main_queue_handle_4CF(void);
extern void _dispatch_main_queue_callback_4CF(void *);
static int installed;

static int drain_dispatch(int fd, int events, void *context) {
    if (events & (ALOOPER_EVENT_ERROR | ALOOPER_EVENT_HANGUP)) return 0;
    uint64_t signal;
    ssize_t count;
    do { count = read(fd, &signal, sizeof(signal)); } while (count == -1 && errno == EINTR);
    if (count != sizeof(signal) && !(count == -1 && errno == EAGAIN)) return 0;
    _dispatch_main_queue_callback_4CF(0);
    return 1;
}

int keyvox_install_main_loop(void) {
    if (gettid() != getpid()) return 0;
    if (installed) return 1;
    ALooper *looper = ALooper_forThread();
    if (!looper) return 0;
    int fd = _dispatch_get_main_queue_handle_4CF();
    if (fd < 0) return 0;
    installed = ALooper_addFd(looper, fd, ALOOPER_POLL_CALLBACK,
        ALOOPER_EVENT_INPUT, drain_dispatch, 0) == 1;
    return installed;
}
