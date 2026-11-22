#import "MUBridge.h"
#import <CoreFoundation/CoreFoundation.h>
#import <mach/mach.h>
#include <signal.h>
#include <errno.h>

// ---------------------------------------------------------------- IOKit (private header thiếu trên iOS SDK)
typedef mach_port_t io_object_t;
typedef io_object_t io_service_t;
typedef io_object_t io_registry_entry_t;

extern CFMutableDictionaryRef IOServiceMatching(const char *name);
extern io_service_t IOServiceGetMatchingService(mach_port_t masterPort, CFDictionaryRef matching);
extern kern_return_t IORegistryEntryCreateCFProperties(io_registry_entry_t entry,
                                                       CFMutableDictionaryRef *properties,
                                                       CFAllocatorRef allocator, uint32_t options);
extern kern_return_t IOObjectRelease(io_object_t object);

NSDictionary *MUReadIORegistry(NSString *serviceName) {
    io_service_t service = IOServiceGetMatchingService(0, IOServiceMatching(serviceName.UTF8String));
    if (!service) return nil;
    CFMutableDictionaryRef props = NULL;
    kern_return_t kr = IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0);
    IOObjectRelease(service);
    if (kr != KERN_SUCCESS || !props) return nil;
    return CFBridgingRelease(props);
}

// ---------------------------------------------------------------- HID thermal sensors (private)
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
extern CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef client);
extern IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef service, int64_t type,
                                                 int32_t options, int64_t timestamp);
extern CFTypeRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service, CFStringRef key);
extern double IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

#define kIOHIDEventTypeTemperature 15
#define IOHIDEventFieldBase(type) ((type) << 16)

NSArray<NSDictionary *> *MUReadThermalSensors(void) {
    static IOHIDEventSystemClientRef client;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ client = IOHIDEventSystemClientCreate(kCFAllocatorDefault); });
    if (!client) return @[];

    NSDictionary *match = @{ @"PrimaryUsagePage": @(0xff00), @"PrimaryUsage": @(5) };
    IOHIDEventSystemClientSetMatching(client, (__bridge CFDictionaryRef)match);
    CFArrayRef services = IOHIDEventSystemClientCopyServices(client);
    if (!services) return @[];

    NSMutableArray *out = [NSMutableArray array];
    CFIndex n = CFArrayGetCount(services);
    for (CFIndex i = 0; i < n; i++) {
        IOHIDServiceClientRef svc = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);
        CFTypeRef nameRef = IOHIDServiceClientCopyProperty(svc, CFSTR("Product"));
        NSString *name = nameRef ? (__bridge_transfer NSString *)nameRef : [NSString stringWithFormat:@"sensor%ld", (long)i];
        IOHIDEventRef ev = IOHIDServiceClientCopyEvent(svc, kIOHIDEventTypeTemperature, 0, 0);
        if (!ev) continue;
        double v = IOHIDEventGetFloatValue(ev, IOHIDEventFieldBase(kIOHIDEventTypeTemperature));
        CFRelease(ev);
        if (v > -50 && v < 200) [out addObject:@{ @"name": name, @"value": @(v) }];
    }
    CFRelease(services);
    return out;
}

// ---------------------------------------------------------------- libproc (không có header trên iOS SDK)
struct mu_proc_taskinfo {
    uint64_t pti_virtual_size, pti_resident_size, pti_total_user, pti_total_system;
    uint64_t pti_threads_user, pti_threads_system;
    int32_t pti_policy, pti_faults, pti_pageins, pti_cow_faults, pti_messages_sent, pti_messages_received;
    int32_t pti_syscalls_mach, pti_syscalls_unix, pti_csw, pti_threadnum, pti_numrunning, pti_priority;
};
extern int proc_listallpids(void *buffer, int buffersize);
extern int proc_pidinfo(int pid, int flavor, uint64_t arg, void *buffer, int buffersize);
extern int proc_name(int pid, void *buffer, uint32_t buffersize);
extern int proc_pidpath(int pid, void *buffer, uint32_t buffersize);
#define MU_PROC_PIDTASKINFO 4

NSArray<NSDictionary *> *MUListProcesses(void) {
    int count = proc_listallpids(NULL, 0);
    if (count <= 0) return @[];
    int *pids = calloc((size_t)count + 64, sizeof(int));
    int bytes = proc_listallpids(pids, (count + 64) * (int)sizeof(int));
    int n = bytes / (int)sizeof(int);
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:n];
    mach_timebase_info_data_t tb; mach_timebase_info(&tb);
    for (int i = 0; i < n; i++) {
        int pid = pids[i];
        if (pid <= 0) continue;
        char name[256] = {0}, path[1024] = {0};
        proc_name(pid, name, sizeof(name));
        proc_pidpath(pid, path, sizeof(path));
        struct mu_proc_taskinfo ti; memset(&ti, 0, sizeof(ti));
        int r = proc_pidinfo(pid, MU_PROC_PIDTASKINFO, 0, &ti, sizeof(ti));
        uint64_t cpuNs = (r == (int)sizeof(ti)) ? (ti.pti_total_user + ti.pti_total_system) * tb.numer / tb.denom : 0;
        [out addObject:@{
            @"pid": @(pid),
            @"name": [NSString stringWithUTF8String:name] ?: @"?",
            @"path": [NSString stringWithUTF8String:path] ?: @"",
            @"resident": @(ti.pti_resident_size),
            @"virtual": @(ti.pti_virtual_size),
            @"threads": @(ti.pti_threadnum),
            @"cpuTime": @(cpuNs),
            @"hasInfo": @(r == (int)sizeof(ti))
        }];
    }
    free(pids);
    return out;
}

int MUKillProcess(int pid, int sig) {
    return kill(pid, sig) == 0 ? 0 : errno;
}
