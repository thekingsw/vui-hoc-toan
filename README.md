# Hành trình khám phá — Toán lớp 5 (MVP)

App học Toán lớp 5 offline, bám SGK Toán 5 *Kết nối tri thức với cuộc sống*.
Flutter + Riverpod + sqflite. Không mạng, không analytics, không quảng cáo.

## Chạy

Thư mục gốc của repo chính là project Flutter:

```bash
flutter pub get
flutter analyze
flutter test
flutter run            # chạy trên máy/emulator
flutter build apk --debug
```

Cần JDK 17 để build Android (Gradle 8.3 + AGP 8.1 không chạy được trên
JDK mới hơn, vd JDK 21/25 sẽ báo "Unsupported class file major version").

## Build bằng GitHub Actions

Repo có workflow `.github/workflows/build-apk.yml`: mỗi lần push lên
`main`, CI tự khôi phục các file nhị phân không nằm trong git (font
Nunito tải từ google/fonts, 2 file âm thanh và 5 icon tự sinh,
`gradle-wrapper.jar` tải từ repo gradle), khôi phục khóa ký từ
GitHub Secrets, rồi chạy `flutter test` và
`flutter build apk --release --split-per-abi`. File APK nằm ở mục
**Artifacts** (`app-release`) cuối trang của lần chạy.

## Tự cập nhật

App tự kiểm tra bản mới trên GitHub Releases mỗi khi mở (chỉ việc này
mới dùng mạng; học vẫn offline). Có bản mới thì app hiện hộp thoại,
bấm "Cập nhật ngay" là tải + cài luôn. Muốn phát hành bản mới: tăng
`version` trong `pubspec.yaml`, push lên `main`, rồi tạo tag `vX.Y.Z`
— CI build xong sẽ tự đăng Release kèm file APK arm64.

Lưu ý: bản release ký bằng khóa riêng (Secrets) nên không cài đè lên
bản debug cũ được — gỡ bản debug một lần rồi cài bản release.

## PIN phụ huynh

PIN mặc định là **`1234`**. Phụ huynh đổi được ngay trong Góc phụ huynh
(mục "Đổi PIN phụ huynh"); PIN lưu trong DB dạng hash FNV-1a — chỉ
chống bé bấm nhầm, không phải bảo mật thật. Reset tiến độ không đổi PIN.

## Dữ liệu

- Dữ liệu thật **280 câu** nằm ở `assets/data/island_*.json`:
  đảo 1 "Ôn Tập" 180 câu (8 bài + boss), đảo 2 "Số thập phân" 100 câu
  (4 bài + boss). Mỗi bài 20 câu (10 mức 1 + 10 mức 2), mỗi boss 20 câu
  (8 mức 1 + 12 mức 2); tỉ lệ loại câu 10 `mcq` + 7 `fill_number` +
  3 `true_false` mỗi bài/boss.
- Loader bỏ qua trường lạ (`calc`, `verified`, `source`...).
  Debug mode validate JSON lúc khởi động (thiếu trường, mcq answer
  không thuộc options, id trùng...).
- App tự xáo thứ tự lựa chọn của câu `mcq` mỗi lần hiển thị, nên bé
  không đoán được đáp án theo vị trí.
- Toàn bộ 280 câu hiện ở trạng thái `verified: false` — chờ rà tay
  theo quy trình trong SPEC (bài toán lời văn + mẫu 20%) trước khi
  chuyển sang `verified: true`.

## Cấu trúc

```
lib/
  main.dart
  models/       Question, Lesson, IslandData
  data/         island_catalog (12 đảo), data_loader
  services/     scoring (chấm điểm, sao, chọn câu, mở khóa, xáo lựa chọn),
                validator, database_service (sqflite),
                sound_service (audioplayers)
  providers/    Riverpod providers
  screens/      splash, home, island, lesson, practice, quiz,
                result, parent
  widgets/      mascot (cáo vẽ bằng CustomPaint), fraction_view,
                star_row, question_view
test/
  scoring_test.dart       chấm điểm (phân số, dấu phẩy), sao, chọn câu,
                          mở khóa, xáo lựa chọn
  validator_test.dart     validate JSON
  bundled_data_test.dart  nạp đúng dữ liệu thật trong assets, đủ 280 câu
```

## Luồng MVP

Home (12 đảo, 2 đảo đầu vào được) → Màn đảo (Học / Luyện tập /
Thử thách) → Lesson (thẻ vuốt ngang) → Practice (10 câu, sai được
gợi ý + thử lại 1 lần) → Quiz cấp đảo (10 câu, phân tầng 4 mức 1 +
6 mức 2, sao ≥6=1, ≥8=2, ≥9=3) → Result. Góc phụ huynh: PIN, đổi PIN,
mở khóa tay từng đảo, reset tiến độ, bật/tắt âm thanh.

## Ghi chú

- Font Nunito kèm trong `assets/fonts/Nunito.ttf` (variable font).
  Nếu font lỗi, Flutter tự rơi về font hệ thống, app vẫn chạy.
- Âm thanh đúng/sai là 2 file wav tự sinh (`assets/sounds/`).
- Chưa có xu/XP, Hộp ôn lại, streak, nhiệm vụ ngày, huy hiệu,
  mini game — các mục này là giai đoạn 2/3 theo SPEC.
