# Max Usage

App iOS (Swift/SwiftUI) giám sát và kiểm soát phần cứng ở mức tối đa, dành cho cài đặt qua TrollStore/sideload.

## Tính năng
- **Tổng quan**: CPU tổng + từng nhân, RAM (used/wired/compressed/free), ổ cứng, GPU %, mạng Wi-Fi/di động (tốc độ), biểu đồ lịch sử, chỉnh tần suất cập nhật
- **Tiến trình**: toàn bộ tiến trình, RAM/CPU/luồng từng cái, tìm kiếm, sắp xếp, vuốt để kill
- **Nhiệt độ**: mọi cảm biến nhiệt HID (CPU/SoC, GPU, NAND, pin, sạc) + `thermalState`
- **Pin**: điện áp, dòng (mA), công suất W, củ sạc, chu kỳ, dung lượng thiết kế/tối đa, độ chai %, ước tính thời gian đầy/hết, nhắc rút sạc
- **Dọn dẹp**: dừng top app nền nặng nhất, xóa cache app này và cache app khác (khi đã bỏ sandbox)
- **Thiết bị**: model, iOS, uptime, cache CPU, màn hình...
- **Widget** (nhỏ, vừa, màn hình khóa) và **Shortcuts/Siri/Action Button** (App Intents)

## Build
Cần máy Mac có Xcode và [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen ldid
xcodegen generate
xcodebuild -project MaxUsage.xcodeproj -scheme MaxUsage -sdk iphoneos \
  -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO
```

Ký giả bằng entitlement đặc quyền rồi đóng IPA:

```sh
APP=build/Build/Products/Release-iphoneos/MaxUsage.app
ldid -SMaxUsage.entitlements "$APP/MaxUsage"
ldid -SMaxUsage.entitlements "$APP/PlugIns/MaxUsageWidget.appex/MaxUsageWidget"
mkdir -p Payload && cp -R "$APP" Payload/ && zip -r MaxUsage.ipa Payload
```
Cài `MaxUsage.ipa` bằng TrollStore. Nếu cài bằng cách sideload thông thường (AltStore...), entitlement đặc quyền bị bỏ nên phần tiến trình, cảm biến HID và kill sẽ không hoạt động. Phần còn lại vẫn chạy.

## Chưa kiểm chứng
Code được viết trên Windows, **chưa biên dịch và chưa chạy thử**. Lần build đầu có thể có lỗi nhỏ cần sửa. Các API private (IOHIDEventSystem, libproc, AppleSmartBattery) thay đổi tên khóa giữa các đời máy/phiên bản iOS, nên có chỗ cần chỉnh theo máy thật.
