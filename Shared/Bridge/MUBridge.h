#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Đọc toàn bộ thuộc tính của 1 service IORegistry (vd "AppleSmartBattery", "IOAccelerator").
NSDictionary *_Nullable MUReadIORegistry(NSString *serviceName);

/// Đọc cảm biến nhiệt qua IOHIDEventSystem (private). Mỗi phần tử: {name, value(°C)}.
NSArray<NSDictionary *> *MUReadThermalSensors(void);

/// Danh sách tiến trình: {pid, name, path, resident(bytes), virtual(bytes), threads, cpuTime(ns)}.
NSArray<NSDictionary *> *MUListProcesses(void);

/// Gửi tín hiệu tới tiến trình. Trả về 0 nếu thành công, errno nếu lỗi.
int MUKillProcess(int pid, int signal);

NS_ASSUME_NONNULL_END
