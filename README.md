# Vita — Sức khỏe & Tài chính

Ứng dụng mobile (Flutter) theo dõi sức khỏe cá nhân kết hợp quản lý tài chính:

- **Calo nạp vào**: chụp ảnh món ăn → AI (Gemini) nhận diện món + ước lượng calo & macro
- **Calo tiêu hao**: đọc từ Health Connect (Android) / HealthKit (iOS), hoặc nhập hoạt động thủ công (MET)
- **Nhắc uống nước**: log lượng nước, notification định kỳ theo khung giờ tùy chỉnh
- **Quản lý tiền**: ghi thu/chi theo danh mục, tổng quan thu — chi — số dư theo tháng

## Tech stack

| Thành phần | Công nghệ |
|---|---|
| App | Flutter 3.50 + Material 3 (`material_ui`), Riverpod 3, GoRouter 18 |
| Backend | Supabase (Auth + PostgreSQL + Storage + Edge Functions) |
| AI | Gemini (`gemini-3-flash-preview`, fallback `gemini-3.1-flash-lite`) qua Edge Function `analyze_food` |
| Sức khỏe | Package `health` 13 (Health Connect / HealthKit) |
| Notification | `flutter_local_notifications` 23 |
| Charts | `fl_chart` |

## Trạng thái backend (đã cấu hình sẵn)

- ✅ Project Supabase: `obhlmobkropguopcmegk` — schema + RLS đã chạy từ `supabase/migrations/0001_initial_schema.sql`
- ✅ Edge Function `analyze_food` đã deploy (verify_jwt + check role=authenticated)
- ✅ Secret `GEMINI_API_KEY` đã set phía server (KHÔNG đặt key này trong `env` — file `env` được đóng gói vào APK)
- ✅ Đã test E2E với ảnh phở: AI trả "Phở bò tái 550g – 450 kcal" chính xác

## Cấu trúc dự án

```
lib/
├── main.dart
├── core/           # theme, router, utils (BMR/TDEE, MET, formatters VND)
├── data/           # supabase client provider
├── features/
│   ├── auth/       # login, signup, profile, BMR/TDEE
│   ├── onboarding/ # thiết lập 4 bước
│   ├── health/     # Health Connect/HealthKit, activity MET, cân nặng
│   ├── nutrition/  # food log, chụp ảnh + AI xác nhận
│   ├── water/      # log nước, notification nhắc định kỳ
│   ├── money/      # giao dịch, danh mục, tổng quan tháng
│   ├── home/       # dashboard + bottom nav
│   ├── reports/    # biểu đồ 7/30 ngày
│   └── settings/
supabase/
├── migrations/     # schema SQL + RLS
└── functions/analyze_food/   # source Edge Function (đã deploy bản v3)
```

## Chạy app

`env` ở gốc dự án đã có sẵn URL + publishable key (không commit). Sau đó:

```bash
flutter pub get
flutter run               # máy Android cắm USB / emulator
flutter build apk --debug # xuất APK
flutter test              # unit test + widget test
flutter analyze
```

## Ghi chú môi trường Windows trên máy này

- Flutter SDK: `D:\flutter` (đã thêm vào PATH user)
- **Smart App Control phải tắt** để build/run được — SAC chặn `dartaotruntime.exe` không chữ ký của Dart SDK (Windows Security → App & browser control → Smart App Control → Off)
- compileSdk = 37, minSdk = 26 (health package yêu cầu), `kotlin.incremental=false` (daemon Kotlin lỗi cache trên Windows)
- Build iOS cần Mac; trên Windows chỉ build được Android

## Tài khoản test đã tạo trên Supabase

- `e2e.tester.vita@gmail.com` / `VitaTest123456` — dùng để kiểm thử đăng nhập nhanh
