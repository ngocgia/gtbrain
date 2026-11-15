# Kế hoạch: Ứng dụng Sức khỏe + Tài chính cá nhân (Flutter)

## Bối cảnh
Xây dựng ứng dụng mobile mới hoàn toàn (thư mục `D:\codeDuAn\GTBrain` đang trống) gồm 2 mảng chính:
1. **Sức khỏe**: theo dõi calo tiêu hao (từ Health Connect/HealthKit), calo nạp vào (chụp ảnh món ăn → Gemini AI nhận diện), nhắc uống nước định kỳ.
2. **Tài chính**: ghi thu/chi theo danh mục, tổng quan thu — chi theo tháng.

**Lựa chọn đã chốt với bạn**: Flutter (mobile) · Gemini API (nhận diện ảnh) · Cloud (Supabase) · Kết nối Health Connect/HealthKit.

## 1. Tech stack

| Thành phần | Công nghệ | Lý do |
|---|---|---|
| Framework | Flutter (stable mới nhất) + Material 3 | Cross-platform Android/iOS từ 1 codebase |
| State management | Riverpod | Test tốt, boilerplate thấp |
| Backend | **Supabase free tier** | Auth + PostgreSQL + Storage (lưu ảnh món ăn) + Edge Functions, không cần thẻ tín dụng. *(Firebase bị loại vì Storage mới yêu cầu gói Blaze trả phí)* |
| AI | Gemini (model flash) gọi qua **Supabase Edge Function** | Giấu API key khỏi app, dùng free tier Google AI Studio |
| Sức khỏe | Package `health` | Đọc Health Connect (Android) & HealthKit (iOS): bước chân, calo hoạt động, nhịp tim |
| Nhắc uống nước | `flutter_local_notifications` | Notification chạy nền, không cần server |
| Charts | `fl_chart` | Biểu đồ calo/nước/tài chính |
| Định dạng tiền | VND mặc định (`intl`) | |

## 2. Kiến trúc & cấu trúc thư mục
```
lib/
├── main.dart
├── core/           # theme, router, utils (BMR/TDEE calc, formatters)
├── data/           # supabase client, repositories, edge function calls
├── features/
│   ├── auth/       # login, signup
│   ├── onboarding/ # profile sơ bộ, mục tiêu
│   ├── health/     # dashboard sức khỏe, calo, hoạt động
│   ├── nutrition/  # food log, chụp ảnh + AI, chi tiết bữa ăn
│   ├── water/      # log nước, cài đặt nhắc nhở
│   ├── money/      # giao dịch, danh mục, tổng quan tháng
│   └── settings/
supabase/
├── migrations/     # schema SQL + RLS
└── functions/analyze_food/   # Edge Function gọi Gemini
```

## 3. Mô hình dữ liệu (PostgreSQL, có RLS — mỗi user chỉ thấy dữ liệu mình)
- `profiles`: giới tính, ngày sinh, chiều cao, cân nặng, mức hoạt động, mục tiêu (giảm/giữ/tăng cân), mục tiêu nước ml/ngày
- `weight_logs`: lịch sử cân nặng
- `food_logs` (bữa: sáng/trưa/tối/snack, ảnh_url, phản hồi AI gốc) → `food_items` (tên món, gram, calo, protein/carb/fat)
- `activity_logs` (nguồn: health_connect/healthkit/thủ công, calo đốt, thời lượng) — snapshot để giữ lịch sử khi đổi máy
- `water_logs` + `water_reminder_settings` (bật/tắt, giờ bắt đầu/kết thúc, khoảng cách nhắc)
- `transaction_categories` (danh mục mặc định + tùy chỉnh, icon, màu) 
- `transactions` (loại thu/chi, số tiền, danh mục, ghi chú, ngày)

## 4. Logic tính toán
- **BMR**: Mifflin-St Jeor → **TDEE** = BMR × hệ số hoạt động
- **Calo tiêu hao**: đọc "active energy + steps" từ thiết bị; cộng activity nhập tay (bảng MET); fallback thuần thủ công nếu chưa cấp quyền
- **AI food**: ảnh (camera/gallery) → Edge Function → Gemini vision → JSON món ăn + gram + calo + macro (ưu tiên prompt món Việt: phở, cơm tấm, bún bò…) → màn hình **xác nhận/chỉnh sửa** rồi mới lưu (AI có thể sai)

## 5. Danh sách màn hình (~14)
Splash · Onboarding 4 bước · Login/Signup · **Home Dashboard** (vòng tròn calo in/out, nước, bước, số dư tháng — bottom nav 4 tab) · Chi tiết Sức khỏe · Food log theo ngày · Chụp ảnh + kết quả AI · Water tracker · Thêm hoạt động thủ công · Danh sách giao dịch · Thêm/sửa giao dịch · Quản lý danh mục · Báo cáo/Thống kê · Cài đặt

## 6. Kế hoạch triển khai theo phase

| Phase | Nội dung | Kết quả kiểm chứng |
|---|---|---|
| **0. Khởi động** | Cài/kiểm tra Flutter SDK, tạo project, theme, cấu trúc folder, khởi tạo Supabase project + migrations schema + RLS, git init | App chạy được màn hình placeholder trên emulator Android |
| **1. Auth + Onboarding** | Đăng ký/đăng nhập email, tạo profile, tính BMR/TDEE, đặt mục tiêu nước mặc định (30ml/kg) | Đăng nhập được, profile lưu vào Supabase |
| **2. Nước + Nhắc nhở** | Log nước (nút nhanh 200ml), biểu đồ trong ngày, cài đặt khoảng nhắc, local notification theo khung giờ | Đặt nhắc mỗi 5 phút → nhận notification |
| **3. Calo nạp + AI** | Edge Function `analyze_food` gọi Gemini, màn chụp ảnh, kết quả AI confirm, food log 4 bữa, tổng calo trong ngày | Chụp ảnh phở → AI trả món + calo → lưu đúng |
| **4. Calo tiêu hao** | Tích hợp package `health`: xin quyền Health Connect/HealthKit, đọc bước + active energy, màn hình sức khỏe, activity thủ công (MET) | Số bước hiển thị khớp với app Sức khỏe của máy |
| **5. Tài chính** | CRUD giao dịch, danh mục mặc định (ăn uống, đi lại, lương…), lọc theo tháng, tổng thu/chi/số dư | Thêm thu + chi → tổng cập nhật đúng |
| **6. Dashboard + Thống kê** | Ghép tất cả vào Home, biểu đồ 7/30 ngày (calo, nước, chi tiêu theo danh mục) | Mở app thấy tổng quan 2 mảng |
| **7. Hoàn thiện** | Dark mode, xử lý lỗi/offline cơ bản, icon app, tên app, build APK release | Cài APK lên máy thật chạy trọn luồng |

Thứ tự trên nhằm: làm core đơn giản trước (auth, nước), phần rủi ro cao (AI, Health Connect) ở giữa khi nền tảng đã chắc.

## 7. Bạn cần chuẩn bị (ngoài code)
1. **Tài khoản Supabase** (free, đăng ký bằng GitHub/Google) — tôi sẽ hướng dẫn tạo project
2. **Gemini API key** miễn phí từ Google AI Studio (aistudio.google.com)
3. **Thiết bị Android** (máy thật hoặc emulator) — Health Connect chạy tốt nhất trên máy thật
4. Lưu ý: build **iOS cần Mac** — trên Windows ta build Android; code vẫn viết iOS-ready

## 8. Kiểm thử
- **Unit test**: công thức BMR/TDEE, MET, format VND, parser JSON từ AI (kể cả response lỗi)
- **Widget test**: dashboard, form giao dịch
- **E2E trên emulator/máy thật**: chạy từng luồng — đăng nhập → log nước → chụp ảnh AI → đọc Health Connect → thêm giao dịch → xem thống kê
- **Edge Function**: test với ảnh món Việt thật, kiểm rate limit & fallback khi AI fail (cho nhập tay)

## 9. Rủi ro & cách xử lý
- **Gemini free tier có giới hạn request/phút** → dùng model flash, cache kết quả món quen thuộc, luôn có fallback nhập tay
- **Health Connect cần cấp quyền trên máy** → nếu bị từ chối, app vẫn chạy chế độ thuần thủ công
- **AI ước lượng calo chỉ ở mức tham khảo** → bắt buộc bước xác nhận trước khi lưu, hiển thị disclaimer
