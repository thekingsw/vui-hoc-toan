// Danh mục 12 đảo — bám bảng mục 3 của SPEC (chuẩn duy nhất).
// Đảo nào chưa có file dữ liệu trong assets thì hiện "Sắp có".

class IslandMeta {
  const IslandMeta({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.order,
    required this.colorValue,
  });

  final String id;
  final String title;
  final String subtitle;
  final int order;

  /// Màu chủ đạo của đảo (ARGB).
  final int colorValue;
}

const List<IslandMeta> islandCatalog = [
  IslandMeta(
    id: 'on_tap_bo_sung',
    title: 'Đảo Ôn Tập',
    subtitle: 'Số tự nhiên, phân số, hỗn số',
    order: 1,
    colorValue: 0xFF2E7D32,
  ),
  IslandMeta(
    id: 'so_thap_phan',
    title: 'Đảo Số Thập Phân',
    subtitle: 'Khái niệm, so sánh, đổi đơn vị, làm tròn',
    order: 2,
    colorValue: 0xFF1565C0,
  ),
  IslandMeta(
    id: 'don_vi_dien_tich',
    title: 'Đảo Diện Tích',
    subtitle: 'km², héc-ta, bảng đơn vị đo diện tích',
    order: 3,
    colorValue: 0xFF6A1B9A,
  ),
  IslandMeta(
    id: 'phep_tinh_thap_phan',
    title: 'Đảo Phép Tính',
    subtitle: 'Cộng, trừ, nhân, chia số thập phân',
    order: 4,
    colorValue: 0xFFE65100,
  ),
  IslandMeta(
    id: 'hinh_phang',
    title: 'Đảo Hình Phẳng',
    subtitle: 'Tam giác, hình thang, hình tròn',
    order: 5,
    colorValue: 0xFF00838F,
  ),
  IslandMeta(
    id: 'on_tap_hk1',
    title: 'Đảo Ôn Học Kì 1',
    subtitle: 'Ôn tập tổng hợp học kì 1',
    order: 6,
    colorValue: 0xFF5D4037,
  ),
  IslandMeta(
    id: 'ti_so',
    title: 'Đảo Tỉ Số',
    subtitle: 'Tỉ số, phần trăm, tỉ lệ bản đồ',
    order: 7,
    colorValue: 0xFFC62828,
  ),
  IslandMeta(
    id: 'the_tich',
    title: 'Đảo Thể Tích',
    subtitle: 'cm³, dm³, m³',
    order: 8,
    colorValue: 0xFF283593,
  ),
  IslandMeta(
    id: 'hinh_khoi',
    title: 'Đảo Hình Khối',
    subtitle: 'Diện tích, thể tích hình hộp, hình lập phương',
    order: 9,
    colorValue: 0xFF4E342E,
  ),
  IslandMeta(
    id: 'thoi_gian_van_toc',
    title: 'Đảo Chuyển Động',
    subtitle: 'Thời gian, vận tốc, quãng đường',
    order: 10,
    colorValue: 0xFF00695C,
  ),
  IslandMeta(
    id: 'thong_ke_xac_suat',
    title: 'Đảo Thống Kê',
    subtitle: 'Biểu đồ hình quạt, tỉ số lặp lại',
    order: 11,
    colorValue: 0xFFAD1457,
  ),
  IslandMeta(
    id: 'on_tap_cuoi_nam',
    title: 'Đảo Ôn Cuối Năm',
    subtitle: 'Ôn tập tổng hợp cả năm',
    order: 12,
    colorValue: 0xFF37474F,
  ),
];

List<String> get islandOrderIds =>
    islandCatalog.map((i) => i.id).toList();
