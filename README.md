# Đảo toán học — Toán lớp 5

App học Toán lớp 5 offline, bám SGK Toán 5 *Kết nối tri thức với cuộc sống*.
Flutter + Riverpod + sqflite. Chỉ Android. Không analytics, không quảng cáo;
mạng chỉ dùng để cập nhật dữ liệu bài học và kiểm tra bản app mới.

12 đảo theo chương trình, mỗi đảo có 3 chế độ **Học** (thẻ kiến thức) →
**Luyện tập** → **Thử thách** (boss, chấm sao). Sao: ≥9 đúng = 3 sao,
≥8 = 2, ≥6 = 1. Boss rút 4 câu mức 1 + 6 câu mức 2.

## Tính năng chính

- **7 loại câu hỏi**: trắc nghiệm (`mcq`), điền số (`fill_number`),
  đúng/sai (`true_false`), nối cặp (`match`), sắp xếp (`order`),
  kéo đơn vị (`drag_unit`), đặt tính cột dọc (`column_calc`).
  Phân số/hỗn số hiển thị tử trên mẫu dưới như SGK.
- **Hình minh họa đúng số đo**: thẻ học và câu hình học kèm hình vẽ
  (tam giác, hình thang, đường tròn, hình hộp, biểu đồ quạt...) qua
  trường `figure` trong dữ liệu.
- **Học thông minh (Đợt A)**: hộp ôn Leitner 5 mức (sai → hộp 1;
  đúng khi ôn → lên hộp; đúng ở hộp 5 → tốt nghiệp), lịch ôn
  1/3/7/14/30 ngày tính theo **đầu ngày** (sai hôm nay, sáng mai ôn được).
  Thẻ "Hôm nay" trên màn chính ưu tiên mời ôn câu đến hạn, rồi mới tới
  bài tiếp theo; có dòng "Cần luyện thêm" theo kỹ năng yếu.
  Khi ôn, app **sinh câu biến thể** (đổi số trong đề theo biểu thức
  `calc` rồi tính lại đáp án bằng phân số chính xác) để bé không nhớ
  đáp án cũ; câu nào không đổi chắc chắn được thì giữ nguyên câu gốc.
- **Phụ huynh + thi thử (Đợt B)**: Góc phụ huynh có bảng theo dõi
  (hoạt động 7 ngày, câu đến hạn ôn, kỹ năng yếu → mạnh kèm tỉ lệ đúng,
  sao từng đảo). **Thi thử**: 20 câu trộn mọi đảo, chấm thang 10,
  xem lời giải câu sai, câu sai tự vào hộp ôn.
- **Cửa hàng**: kiếm xu khi học, mua đồ mặc cho linh vật cáo
  (mũ, kính, khăn, áo choàng, thú cưng) và thuyền/cờ cho bản đồ;
  vị trí món trên linh vật khai trong `assets/config/shop_items.json`
  (trường `anchor`).
- Giao diện Claymorphism + font Baloo 2 (tiêu đề) / Nunito (thân),
  ảnh đảo và nền cảnh sinh bằng AI.

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
`main`, CI khôi phục các file nhị phân không nằm trong git (font,
ảnh `.webp` giải mã từ file `.webp.b64` đi kèm, âm thanh,
`gradle-wrapper.jar`), khôi phục khóa ký từ GitHub Secrets, chạy
`flutter test` rồi `flutter build apk --release --split-per-abi`, và
**tự đăng Release** theo `version` trong `pubspec.yaml` kèm APK arm64
(tag đã tồn tại thì ghi đè asset).

Muốn phát hành bản mới: tăng `version` trong `pubspec.yaml` rồi push.
Lưu ý: **số build sau dấu `+` phải luôn tăng** so với bản trước
(versionCode = số build × hệ số của Flutter); nếu không, Android từ
chối cài đè dù versionName cao hơn.

App tự kiểm tra bản mới trên GitHub Releases mỗi khi mở; có bản mới thì
hiện hộp thoại, bấm "Cập nhật ngay" là tải + cài luôn. Bản release ký
bằng khóa riêng (Secrets) nên không cài đè lên bản debug cũ được —
gỡ bản debug một lần rồi cài bản release.

## PIN phụ huynh

PIN mặc định là **`1234`**. Phụ huynh đổi được ngay trong Góc phụ huynh
(mục "Đổi PIN phụ huynh"); PIN lưu trong DB dạng hash FNV-1a — chỉ
chống bé bấm nhầm, không phải bảo mật thật. Reset tiến độ không đổi PIN.

## Dữ liệu

- **Dữ liệu bài học không nằm trong repo này** (repo public). Nguồn dữ
  liệu là app **Soạn bài** (web nội bộ): app điện thoại tải gói dữ liệu
  qua `/sync/manifest.json` + `/sync/islands/<id>.json` mỗi khi mở app
  (và bấm kiểm tra trong Góc phụ huynh). Trong assets chỉ giữ đảo 1
  đóng gói dự phòng để app chạy được khi chưa có mạng lần đầu.
- Đã xuất bản 4 đảo đầu (đảo 1–4, 464 câu); đảo 5–12 đang soạn dần.
  Chỉ bài đã duyệt trong Soạn bài mới sang điện thoại.
- Chuẩn mỗi bài: 20 câu (10 mức 1 + 10 mức 2) + 4–5 thẻ học; boss:
  20 câu (8 mức 1 + 12 mức 2), không thẻ. Câu có trường `calc`
  (biểu thức kiểm chứng) để app sinh biến thể khi ôn; câu `true_false`
  và `mcq` đáp án kèm đơn vị thì không có `calc`.
- Loader bỏ qua trường lạ; câu có loại chưa hỗ trợ bị lọc bỏ thay vì
  làm vỡ app. App tự xáo thứ tự lựa chọn của câu `mcq` mỗi lần hiển thị.

## Cấu trúc

```
lib/
  main.dart
  models/       Question, Lesson, IslandData
  data/         island_catalog (12 đảo), data_loader
  services/     scoring (chấm điểm, sao, chọn câu, xáo lựa chọn),
                validator, database_service (sqflite),
                content_store (nạp/lọc dữ liệu), data_update_service
                (tải gói dữ liệu), update_service (kiểm tra bản mới),
                review_logic (hộp ôn Leitner), variant_generator
                (sinh câu biến thể từ calc), sound_service
  game/         question_play_area (luồng trả lời dùng chung),
                shop/ (cửa hàng, tủ đồ, linh vật mặc đồ),
                map/, scene/ (cảnh đảo), effects/, result/
  providers/    Riverpod providers
  screens/      splash, home, island, lesson, practice, quiz,
                result, review (ôn lại), exam (thi thử), parent
  widgets/      mascot (cáo ảnh thật), figure_view (vẽ hình đúng số đo),
                fraction_view, star_row, question_view
  theme/        game_theme (GameColors, Claymorphism)
test/
  scoring_test.dart          chấm điểm (phân số, dấu phẩy), sao, chọn câu
  validator_test.dart        validate JSON + cấu trúc 7 loại câu
  review_logic_test.dart     hộp ôn, lịch đến hạn, điểm thi thử
  variant_generator_test.dart  tính calc + sinh biến thể
  figure_view_test.dart      vẽ hình minh họa
  rewards_test.dart          xu/cửa hàng
  game_state_test.dart, data_update_test.dart, update_service_test.dart
  bundled_data_test.dart     nạp dữ liệu dự phòng trong assets
```

## Luồng chơi

Home (12 đảo + thẻ Hôm nay + nút Thi thử + cửa hàng) → Màn đảo
(Học / Luyện tập / Thử thách) → Lesson (thẻ vuốt ngang) → Practice
(sai được gợi ý + thử lại) → Quiz cấp đảo (sao) → Result.
Ôn lại: từ thẻ Hôm nay khi có câu đến hạn. Thi thử: nút trên hàng
HUD màn chính. Góc phụ huynh: PIN, bảng theo dõi, mở khóa tay từng
đảo, reset tiến độ, âm thanh, kiểm tra dữ liệu mới.
