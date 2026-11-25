# Hành trình khám phá — Toán lớp 5 (MVP)

App học Toán lớp 5 offline, bám SGK Toán 5 *Kết nối tri thức với cuộc sống*.
Flutter + Riverpod + sqflite. Không mạng, không analytics, không quảng cáo.

## Chạy

```bash
export PATH=~/workspace/flutter/bin:$PATH
cd app
flutter pub get
flutter analyze
flutter test
flutter run            # chạy trên máy/emulator
flutter build apk --debug
```

## PIN phụ huynh mặc định

**`1234`** (xem `lib/services/database_service.dart`, hằng `defaultParentPin`).
Lưu trong DB dạng hash FNV-1a — chỉ chống bé bấm nhầm, không phải bảo mật thật.

## Dữ liệu

- Dữ liệu thật (280 câu) sẽ nằm ở `app/assets/data/island_*.json`
  (do agent dữ liệu sinh, xem `../docs/SPEC_data_generation_lop5.md`).
- Hiện tại trong repo là **dữ liệu mẫu**: `island_on_tap_bo_sung.json`
  và `island_so_thap_phan.json` (mỗi đảo 2 lesson mẫu + boss 10 câu,
  đủ 3 loại `mcq` / `fill_number` / `true_false`).
  Khi file thật thay vào đúng tên file, loader đọc thẳng không cần sửa code.
- Loader bỏ qua trường lạ (`calc`, `verified`, `source`...).
  Debug mode validate JSON lúc khởi động (thiếu trường, mcq answer
  không thuộc options, id trùng...).

## Cấu trúc

```
lib/
  main.dart
  models/       Question, Lesson, IslandData
  data/         island_catalog (12 đảo), data_loader
  services/     scoring (chấm điểm, sao, chọn câu, mở khóa),
                validator, database_service (sqflite),
                sound_service (audioplayers)
  providers/    Riverpod providers
  screens/      splash, home, island, lesson, practice, quiz,
                result, parent
  widgets/      mascot (cáo vẽ bằng CustomPaint), fraction_view,
                star_row, question_view
test/
  scoring_test.dart    chấm điểm (,/ .), sao, chọn câu, mở khóa
  validator_test.dart  validate JSON
```

## Luồng MVP

Home (12 đảo, 2 đảo đầu vào được) → Màn đảo (Học / Luyện tập /
Thử thách) → Lesson (thẻ vuốt ngang) → Practice (10 câu, sai được
gợi ý + thử lại 1 lần) → Quiz cấp đảo (10 câu, phân tầng 4 mức 1 +
6 mức 2, sao ≥6=1, ≥8=2, ≥9=3) → Result. Góc phụ huynh: PIN,
mở khóa tay từng đảo, reset tiến độ, bật/tắt âm thanh.

## Build APK — ghi chú môi trường

Trên VM này, `flutter build apk --debug` **chưa build được** (xem chi tiết
trong báo cáo bàn giao). Nguyên nhân đã xác định: sandbox chặn TCP đi
của tiến trình Java — client của Gradle daemon nhận được thông báo
chặn thay cho dữ liệu daemon (`Unexpected type tag 109`, byte đầu là
`m` của "muse: Other TCP connections is turned off..."). Kiểm chứng:
socket loopback Python ↔ Python vẫn chạy, Java client → bất cứ đâu
đều nhận đúng thông báo chặn đó. Code app không có lỗi — `analyze`
sạch và 30/30 test pass. Muốn có APK thì build trên máy không bị
chặn Java TCP (vd. PC anh có Android Studio, hoặc máy 92).

Các bước chuẩn bị đã làm xong trên VM (để lần build sau nhanh hơn):
- `flutter pub get` xong (61 dependencies).
- Gradle 8.3 đã tải về `~/.gradle/wrapper/dists/gradle-8.3-all/6en3ugtfdg5xnpx44z4qbwgas/`
  (chú ý: thư mục hash của wrapper KHÔNG phải sha256 hex của URL).
- License Android đã tạo tay trong `~/workspace/android-sdk/licenses/`
  (sdkmanager không chạy được qua proxy).
- Build cần: `JAVA_HOME=~/workspace/jdk-17`,
  `ANDROID_HOME=~/workspace/android-sdk`,
  `GRADLE_USER_HOME=/home/hatch/.gradle` (Java lấy `user.home=/root`
  nên không đặt biến này thì wrapper tìm nhầm chỗ),
  `GRADLE_OPTS` với proxy `hatch-egress-proxy:3128` (lấy user/pass
  từ `$https_proxy` lúc chạy, không ghi vào file).

- Font Nunito kèm trong `assets/fonts/Nunito.ttf` (variable font).
  Nếu font lỗi, Flutter tự rơi về font hệ thống, app vẫn chạy.
- Âm thanh đúng/sai là 2 file wav tự sinh (`assets/sounds/`).
- Chưa có xu/XP, Hộp ôn lại, streak, nhiệm vụ ngày, huy hiệu,
  mini game — các mục này là giai đoạn 2/3 theo SPEC.
