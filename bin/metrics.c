#include <mach/mach.h>
#include <mach/host_info.h>
#include <mach/vm_statistics.h>
#include <sys/file.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <CoreFoundation/CoreFoundation.h>

// Apple Silicon die temperatures are exposed through IOKit's HID event system.
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;
IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef);
int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef, CFDictionaryRef);
CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef);
IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef, int64_t, int32_t, int64_t);
CFTypeRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef, CFStringRef);
double IOHIDEventGetFloatValue(IOHIDEventRef, int32_t);

static double die_temp(void) {
    int page = 0xff00;
    int usage = 5;
    double hottest = 0;
    IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreate(NULL);
    if (!client) {
        return 0;
    }

    CFNumberRef p = CFNumberCreate(NULL, kCFNumberIntType, &page);
    CFNumberRef u = CFNumberCreate(NULL, kCFNumberIntType, &usage);
    const void *keys[] = {CFSTR("PrimaryUsagePage"), CFSTR("PrimaryUsage")};
    const void *values[] = {p, u};
    CFDictionaryRef matching = CFDictionaryCreate(NULL, keys, values, 2,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    IOHIDEventSystemClientSetMatching(client, matching);
    CFArrayRef sensors = IOHIDEventSystemClientCopyServices(client);
    CFIndex count = sensors ? CFArrayGetCount(sensors) : 0;
    for (CFIndex i = 0; i < count; i++) {
        IOHIDServiceClientRef sensor = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(sensors, i);
        char name[64] = "";
        CFTypeRef product = IOHIDServiceClientCopyProperty(sensor, CFSTR("Product"));
        if (product) {
            if (CFGetTypeID(product) == CFStringGetTypeID()) {
                CFStringGetCString(product, name, sizeof name, kCFStringEncodingUTF8);
            }
            CFRelease(product);
        }
        if (!strstr(name, "tdie")) {
            continue;
        }
        IOHIDEventRef event = IOHIDServiceClientCopyEvent(sensor, 15, 0, 0);
        if (event) {
            double t = IOHIDEventGetFloatValue(event, 15 << 16);
            CFRelease(event);
            if (t < 150 && t > hottest) {
                hottest = t;
            }
        }
    }
    if (sensors) {
        CFRelease(sensors);
    }
    CFRelease(matching);
    CFRelease(p);
    CFRelease(u);
    CFRelease(client);
    return hottest;
}

struct cpu_sample {
    unsigned long long total;
    unsigned long long idle;
};

static bool sample_cpu(host_t host, struct cpu_sample *sample) {
    host_cpu_load_info_data_t cpu;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    if (host_statistics(host, HOST_CPU_LOAD_INFO, (host_info_t)&cpu, &count) != KERN_SUCCESS) {
        return false;
    }
    sample->total = 0;
    sample->idle = cpu.cpu_ticks[CPU_STATE_IDLE];
    for (int i = 0; i < CPU_STATE_MAX; i++) {
        sample->total += cpu.cpu_ticks[i];
    }
    return true;
}

static bool delta_is_valid(struct cpu_sample previous, struct cpu_sample current) {
    return previous.total > 0 && current.total > previous.total && current.idle >= previous.idle &&
        current.idle - previous.idle <= current.total - previous.total;
}

static double cpu_usage(host_t host, const char *path, bool instant) {
    struct cpu_sample previous = {0};
    struct cpu_sample current;
    double usage = 0;
    FILE *cache = !instant && path ? fopen(path, "a+") : NULL;
    if (cache) {
        if (flock(fileno(cache), LOCK_EX) == 0) {
            rewind(cache);
            if (fscanf(cache, "%llu %llu %lf", &previous.total, &previous.idle, &usage) < 2) {
                previous = (struct cpu_sample){0};
            }
        } else {
            fclose(cache);
            cache = NULL;
        }
    }

    if (sample_cpu(host, &current)) {
        if (!previous.total || current.total < previous.total || current.idle < previous.idle) {
            // A fresh install, reboot, or wrapped counters needs a second reading.
            previous = current;
            struct timespec delay = {.tv_nsec = 100 * 1000 * 1000};
            nanosleep(&delay, NULL);
            sample_cpu(host, &current);
        }
        if (delta_is_valid(previous, current)) {
            usage = 100.0 * (1.0 - (double)(current.idle - previous.idle) /
                (double)(current.total - previous.total));
        }
        if (cache && ftruncate(fileno(cache), 0) == 0) {
            fprintf(cache, "%llu %llu %.0f\n", current.total, current.idle, usage);
        }
    }
    if (cache) {
        fclose(cache);
    }
    return usage >= 0 && usage <= 100 ? usage : 0;
}

int main(int argc, char **argv) {
    const char *path = NULL;
    bool temperature = true;
    bool instant = false;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--no-temperature") == 0) {
            temperature = false;
        } else if (strcmp(argv[i], "--instant") == 0) {
            instant = true;
        } else if (!path) {
            path = argv[i];
        } else {
            return 2;
        }
    }

    host_t host = mach_host_self();
    vm_statistics64_data_t vm;
    vm_size_t page_size;
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    if (host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&vm, &count) != KERN_SUCCESS ||
        host_page_size(host, &page_size) != KERN_SUCCESS) {
        return 1;
    }

    uint64_t used = ((uint64_t)vm.active_count + vm.wire_count + vm.compressor_page_count) * page_size;
    printf("%.0f %.1f %.0f\n", cpu_usage(host, path, instant),
        (double)used / 1073741824.0, temperature ? die_temp() : 0);
    return 0;
}
