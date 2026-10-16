# Lockit

Ứng dụng Flutter cho **Android và iPhone**: chụp ảnh hằng ngày và chia sẻ với những người đã đồng ý kết bạn. Giao diện tiếng Việt, dùng Supabase cho tài khoản, cơ sở dữ liệu và lưu ảnh riêng tư.

## Tính năng hiện tại (0.2)

- Đăng ký bằng email, mật khẩu, tên hiển thị và tên người dùng duy nhất.
- Đăng nhập; phiên đăng nhập được Supabase lưu trên thiết bị; đăng xuất.
- Kết bạn bằng tên người dùng: gửi, nhận, chấp nhận, từ chối, thu hồi và hủy kết bạn.
- Chụp ảnh, đổi camera, flash tự động nếu máy hỗ trợ, xem trước và chú thích.
- Bảng tin có phân trang, kéo xuống tải lại, thả tim, xóa ảnh của mình.
- Hồ sơ cá nhân: sửa tên hiển thị, giới thiệu, biểu tượng và màu đại diện; sao chép tên người dùng.
- Tìm bạn bè trong danh sách, hiển thị số lời mời và chấp nhận tên được dán có dấu `@`.
- Kỷ niệm có lịch tiếng Việt để lọc theo ngày tại múi giờ của điện thoại.
- Chạm ảnh để xem toàn màn hình và phóng to bằng hai ngón tay.
- Bảng tin chỉ tải ảnh gần vùng đang xem, tránh tải cả album cùng lúc.
- Ảnh chỉ có thể được tải bởi chủ ảnh và bạn bè hiện tại. Bạn bè mới có thể xem ảnh cũ. Hủy kết bạn chặn các yêu cầu đọc tiếp theo; ảnh đã xem hoặc chụp màn hình không thể thu hồi.

Chưa có widget màn hình chính, thông báo đẩy, chat, chọn người nhận riêng, tải ảnh đại diện từ thư viện hay quy trình xóa tài khoản. Đây là bản phát triển, chưa phải bản đã phát hành trên App Store/Google Play. Trước khi phát hành cần bổ sung xóa tài khoản, chặn/báo cáo người dùng, chính sách quyền riêng tư và kiểm thử thiết bị thật.

## Trải nghiệm trước khi có Supabase

Có thể thử giao diện, camera, lưu ảnh trong phiên, thả tim và thao tác kết bạn mẫu mà không cần tài khoản hay kết nối máy chủ:

```sh
flutter run --dart-define=DEMO_MODE=true -d DEVICE_ID
flutter build apk --debug --target-platform android-arm64 --dart-define=DEMO_MODE=true
```

Bản trải nghiệm có nhãn rõ ràng, bạn bè mẫu `@linh_demo` và `@minh_demo`. Ảnh không được gửi đến người khác, chỉ giữ trong bộ nhớ của phiên; đăng xuất hoặc khởi động lại app sẽ mất ảnh thử. App cố gắng dọn file tạm do camera tạo ra sau khi đọc ảnh vào bộ nhớ. Bản Android này dành cho điện thoại 64-bit và dùng chữ ký debug để thử nghiệm. Khi kết nối Supabase thật, build bằng `config/local.json` theo hướng dẫn bên dưới và **bỏ `DEMO_MODE=true`**.

### APK Android trải nghiệm

Tải ZIP tại [GitHub Releases](https://github.com/dangminhquangfpc-gif/Lockit/releases). Giải nén và mở APK trên điện thoại Android 64-bit (Android 5.0/API 21 trở lên); cho phép camera khi app hỏi. Chữ ký APK và cấu trúc ZIP được kiểm tra trong workflow, nhưng camera vẫn cần kiểm tra trên điện thoại thật.

Các bản thử được ký bằng khóa debug của máy build. Nếu Android báo không thể cập nhật bản cũ do chữ ký khác nhau, hãy gỡ bản thử cũ rồi cài APK mới. Dữ liệu demo chỉ nằm trong phiên, không phải ảnh đã được đồng bộ lên tài khoản.

Trong cloud, khôi phục đường dẫn công cụ trước khi chạy lệnh:

```sh
. /workspace/.tools/lockit-android-env.sh
cd /workspace/Lockit
flutter analyze
flutter test --reporter expanded
flutter build apk --debug --no-pub --target-platform android-arm64 --dart-define=DEMO_MODE=true
```

Android SDK/JDK và cấu hình proxy/chứng chỉ nằm ngoài mã nguồn trong `/workspace/.tools`. Máy của bạn có thể dùng Android Studio để cài SDK và cấu hình JDK 17 theo `flutter doctor`; không dùng địa chỉ proxy của cloud trên điện thoại hay máy cá nhân.

## 1. Tạo Supabase (không cần gửi khóa trong chat)

1. Vào <https://supabase.com/dashboard>, đăng nhập và chọn **New project**. Tạo tên dự án, mật khẩu cơ sở dữ liệu riêng và chọn vùng gần người dùng.
2. Khi dự án sẵn sàng, mở **SQL Editor** và chạy lần lượt hai file bên dưới, **mỗi file một lần**:
   - [001 — tài khoản, kết bạn và ảnh riêng tư](supabase/migrations/202610160001_social.sql).
   - [002 — hồ sơ, giới thiệu và biểu tượng đại diện](supabase/migrations/202610160002_profiles.sql).
   - [003 — phản hồi ảnh và trả lời với emoji](supabase/migrations/202610160003_comments.sql).

   Nếu trước đây đã chạy file 001, chỉ chạy thêm file 002. Giữ bucket `moments` riêng tư và giữ nguyên RLS. Hồ sơ (tên, giới thiệu, biểu tượng) hiển thị trong ứng dụng; ảnh vẫn chỉ được đọc bởi chủ ảnh và bạn bè hiện tại.
3. Trong **Authentication → Providers → Email**, bật đăng nhập email/mật khẩu. Giữ xác nhận email cho môi trường thật. Với email xác nhận mặc định, người dùng xác nhận trong trình duyệt rồi quay lại app đăng nhập; không cần deep link ở bản này. Cấu hình Site URL hợp lệ nếu cần trang xác nhận riêng.
4. Trong phần **Connect / API settings** của dự án, lấy **Project URL** và khóa **publishable** (hoặc `anon` công khai ở dự án cũ).
5. Sao chép `config/example.json` thành `config/local.json`, thay hai giá trị bằng URL và khóa công khai của dự án. File local đã được Git bỏ qua.

**Không dùng khóa `service_role`, secret key hoặc mật khẩu cơ sở dữ liệu trong ứng dụng.** Khóa công khai được đóng gói vào app; bảo mật nằm ở Supabase Auth và các chính sách RLS trong migration. Không tắt RLS để sửa lỗi kết nối.

Nếu tên người dùng đã có, Supabase sẽ từ chối đăng ký; thử tên khác. Dự án đã có tài khoản trước migration cần tạo hồ sơ tương ứng riêng; hướng dẫn này dành cho dự án mới.

## 2. Chạy trên Android và iPhone

Toolchain tham chiếu: Flutter **3.16.5** / Dart **3.2.3**, JDK **17**, Android SDK theo `flutter doctor`, iOS tối thiểu **12.0** và Android tối thiểu **21**. Dùng phiên bản này để tái hiện kiểm thử; nâng cấp Flutter/toolchain và kiểm thử lại trước khi phát hành. Khi dùng iPhone cần máy Mac có Xcode và CocoaPods. Camera cần thiết bị thật hoặc emulator có camera được cấu hình.

Từ thư mục gốc dự án:

```sh
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run --dart-define-from-file=config/local.json -d DEVICE_ID
```

- **Android:** bật Developer options/USB debugging, kết nối điện thoại, chọn device ID. `flutter build apk --debug --dart-define-from-file=config/local.json` tạo APK thử nghiệm. Dự án dùng Gradle 7.5/AGP 7.3 và cần JDK 17; nâng cấp cho yêu cầu phát hành hiện hành.
- **iPhone:** mở `ios/Runner.xcworkspace` trên Mac, chọn Apple development team và bundle identifier của bạn trong Signing & Capabilities. Chạy `flutter run ...` với ID iPhone. Cấp quyền camera khi app hỏi. Nếu từng từ chối, bật lại trong Cài đặt → Lockit → Camera.
- App không ghi âm và không yêu cầu quyền đọc toàn bộ thư viện ảnh. Ảnh tải lên là JPEG, tối đa 10 MB, chú thích tối đa 280 ký tự.
- Khi thiếu cấu hình, app hiển thị trạng thái đang chuẩn bị; khi camera bị từ chối hoặc không có camera, app hiển thị nút thử lại.

## 3. Kiểm thử

```sh
flutter test
cd tools
npm ci --ignore-scripts
npm test
```

40 kiểm thử Flutter kiểm tra xác thực đầu vào, lời mời đến/đi, gửi lời mời, tải lại khi mất kết nối, điều hướng, đăng xuất, lỗi camera và chế độ trải nghiệm. Kiểm thử SDK Supabase dùng HTTP mô phỏng để kiểm tra đăng ký với PKCE, thông báo xác nhận email/sai mật khẩu, JPEG multipart, dọn file khi đăng bài thất bại, tải ảnh có xác thực và phân trang. Các bài này không gọi Supabase thật. Kiểm thử bổ sung bao gồm sửa hồ sơ/giữ dữ liệu khi lưu lỗi, lịch chọn ngày, tìm bạn, xem ảnh lớn, tải ảnh theo vùng nhìn thấy và tên người dùng dài trên màn hình hẹp. Kiểm thử PostgreSQL chạy migration và 64 kiểm tra quyền truy cập bằng PGlite, với schema Auth/Storage tối giản cho môi trường kiểm thử. Nó không thay thế kiểm thử dịch vụ Supabase thật.

### Kiểm tra hai thiết bị trước khi dùng thật

1. Đăng ký A trên Android và B trên iPhone, xác nhận email rồi đăng nhập.
2. A chụp một ảnh. B chưa kết bạn phải không thấy ảnh.
3. A gửi lời mời tới tên B. B vẫn không thấy ảnh khi chưa chấp nhận. A không được tự chấp nhận lời mời mình gửi.
4. B chấp nhận. Kéo tải lại bảng tin trên cả hai máy: B thấy ảnh A, có thể thả tim; A thấy số tim. B chụp ảnh và A thấy ảnh đó.
5. A hủy kết bạn. B tải lại: ảnh A biến mất; API tải ảnh bằng phiên B phải bị từ chối. Không dùng URL công khai để kiểm tra.
6. Sửa hồ sơ A; tải lại phía B để kiểm tra tên/biểu tượng mới. A không thể sửa hồ sơ B bằng API.
7. Tạo ảnh gần nửa đêm theo múi giờ điện thoại, chọn ngày trong Kỷ niệm và kiểm tra ảnh không bị lệch sang ngày bên cạnh. Thử cùng bộ lọc khi tải trang tiếp theo.
8. Kiểm tra từ chối/thu hồi lời mời, tìm bạn bằng tên, chụp lại, xóa ảnh, xem ảnh lớn, đăng xuất/đăng nhập lại, mất mạng, từ chối camera, đổi camera và đưa app ra nền rồi mở lại.

## Cấu trúc

- `lib/ui`: giao diện chính, tài khoản, camera, bạn bè, bảng tin.
- `lib/data`: mô hình, thao tác Supabase và kho dữ liệu trải nghiệm trong bộ nhớ.
- `supabase/migrations`: cơ sở dữ liệu, quyền RLS và bucket riêng tư.
- `tools/policy_test.mjs`: kiểm thử PostgreSQL cho quyền truy cập.

Ứng dụng hiện dùng kéo để cập nhật bảng tin; chưa đăng ký Supabase Realtime. Không cần khóa quản trị trên điện thoại.

## Nguồn ban đầu

Dựa trên giao diện camera Locket Clone của Nasr Al-Rahbi ([@abom_me](https://twitter.com/abom_me)). Giữ giấy phép MIT trong `LICENSE`.

### Phản hồi về ảnh

Bấm **Phản hồi** bên dưới ảnh để gửi tin nhắn hoặc emoji. Bấm **Trả lời** trên một phản hồi để trích dẫn, rồi nhập nội dung; nút × hủy lựa chọn trả lời. Phản hồi mới nhất ở dưới, có nút tải các phản hồi trước và nút làm mới. Nội dung tối đa 500 ký tự Unicode; gửi lỗi giữ bản nháp để thử lại.

Trong demo, **Thêm phản hồi mẫu từ Linh** tạo dữ liệu mẫu ngay trên máy để thử trả lời. Chưa có tin nhắn thật giữa hai thiết bị. Khi dùng Supabase, chỉ chủ ảnh và bạn bè hiện tại được đọc/gửi; hủy kết bạn thu hồi quyền truy cập, xóa ảnh xóa các phản hồi. Chạy migration 003 sau 001 và 002. Chưa có thông báo đẩy hay đồng bộ phản hồi thời gian thực; bấm làm mới để xem phản hồi mới.
