# Mini-Project 3: OCR Expense Tracker & Receipt Parser (Flutter & Dart)

> **Môn học:** Lập Trình Đa Nền Tảng (Cross-Platform Programming)  
> **Công nghệ:** Flutter 3.x • Dart 3 • Google ML Kit On-Device Text Recognition • SQLite (`sqflite`) • CustomPainter

---

## 📱 Giới thiệu tổng quan (Project Overview)

Sinh viên và thủ quỹ các câu lạc bộ thường xuyên phải xử lý số lượng lớn hóa đơn giấy (siêu thị, quán cafe, nhà sách, đi lại, linh kiện...). Việc nhập thủ công từng con số vào bảng tính Excel rất tốn thời gian và dễ xảy ra sai sót.

**OCR Expense Tracker** là ứng dụng Flutter quản lý tài chính cá nhân tích hợp **Trí tuệ nhân tạo On-Device (Google ML Kit)** và **Bộ máy Heuristic Regex thông minh**, cho phép:
- Quét hóa đơn trực tiếp bằng camera ngoại tuyến (offline, sub-100ms, 0đ chi phí cloud).
- Tự động bóc tách: **Tên cửa hàng (Merchant)**, **Tổng tiền thanh toán (Total Amount)**, **Ngày giao dịch (Date)** và **Phân loại danh mục (Category)**.
- Quản lý giao dịch nội bộ bằng SQLite với lưu trữ ảnh thumbnail hóa đơn.
- Trực quan hóa dữ liệu chi tiêu qua **Biểu đồ tròn (Donut Chart)** và **Biểu đồ cột (Weekly Bar Chart)** được vẽ hoàn toàn bằng **`CustomPainter`** (không dùng bất kỳ thư viện biểu đồ bên thứ ba nào).

---

## 🎯 4 Đặc tả chức năng cốt lõi (Core Specifications)

### 1. Camera Capture & Image Cropping
- **Live Viewfinder**: Kính ngắm camera thời gian thực với độ phân giải cao (`ResolutionPreset.high`).
- **Focus & Exposure Tap**: Chạm vào bất kỳ điểm nào trên màn hình để lấy nét (`setFocusPoint`) và đo sáng, kèm hiệu ứng khung ngắm lấy nét động.
- **Flash Toggle**: Hỗ trợ 4 chế độ đèn flash (Tắt, Tự động, Luôn bật, Đèn pin - Torch).
- **Framing Crop Overlay**: Lớp phủ căn chỉnh hóa đơn với hiệu ứng 4 góc bracket chuyên nghiệp phong cách Document Scanner, tự động crop vùng ảnh hóa đơn trước khi đưa vào nhận diện OCR.
- **Gallery & Mock Samples**: Tích hợp chọn ảnh từ thư viện (`image_picker`) và menu nạp hóa đơn mẫu (WinMart, Highlands Coffee, Fahasa, Grab...) để kiểm thử tức thì cả trên thiết bị thật, máy ảo Android lẫn Desktop.

### 2. On-Device Text Recognition & Regex Heuristics
- **Google ML Kit Text Recognition**: Nhận diện ký tự quang học offline sub-100ms trên thiết bị với bảng chữ cái Latin (`google_mlkit_text_recognition`).
- **Heuristic Regex Engine (`ReceiptHeuristicParser`)**:
  - **Bóc tách tổng tiền**: Xử lý định dạng tiền tệ Việt Nam và quốc tế (`150.000 đ`, `150,000 VND`, `215.000`, `150k`). Phân biệt chính xác giữa **Tổng thanh toán** và **Tiền thối/tiền thừa/tiền khách đưa** qua bộ lọc Negative Keywords.
  - **Bóc tách ngày tháng**: Định dạng `DD/MM/YYYY`, `DD-MM-YYYY`, `YYYY-MM-DD`, `Ngày: ...`.
  - **Nhận diện Merchant**: Kết hợp danh từ điển chuỗi cửa hàng phổ biến tại Việt Nam (WinMart, Highlands Coffee, Fahasa, CellphoneS, Grab, CGV...) và phân tích tiêu đề hóa đơn (Header Scan).
  - **Phân loại tự động (Auto-Categorization)**: Suy luận thông minh vào 5 danh mục: `Food`, `Study`, `Travel`, `Gear`, `Entertainment`.
  - **Màn hình Review tương tác (`ReceiptReviewScreen`)**: Cho phép người dùng kiểm tra độ tin cậy AI (Confidence Score), chỉnh sửa số tiền, tên cửa hàng, ngày, ghi chú, xem các ứng viên số tiền OCR gợi ý, và bảng chẩn đoán mã OCR Raw.

### 3. Local Database & Transaction Lifecycle
- **Cơ sở dữ liệu SQLite (`sqflite`)**:
  - Bảng `expenses` được đánh index tại cột `date` và `category` nhằm tối ưu tốc độ truy vấn biểu đồ và thống kê.
  - Hỗ trợ đầy đủ các thao tác CRUD (Thêm, Xem, Sửa, Xóa có xác nhận & Undo).
  - Tìm kiếm toàn văn theo tên cửa hàng hoặc ghi chú.
  - Bộ lọc chip danh mục tương tác trên màn hình chính.
- **Quản lý Thumbnail Cache (`ThumbnailService`)**:
  - Nén và thu nhỏ ảnh hóa đơn (`image` package) lưu vào thư mục ứng dụng nội bộ (`path_provider`).
  - Tự động xóa file cache trên bộ nhớ khi người dùng xóa giao dịch.

### 4. Custom Canvas Visualizations with `CustomPainter`
> ⚡ **Tuân thủ 100% yêu cầu đề bài:** Tuyệt đối **KHÔNG** sử dụng thư viện biểu đồ bên thứ 3 (như `fl_chart`, `syncfusion_flutter_charts`). Toàn bộ biểu đồ được vẽ trực tiếp lên Canvas bằng `CustomPainter` và `AnimationController`.

- **Animated Donut / Pie Chart (`AnimatedDonutChart`)**:
  - Hiệu ứng quét cung góc động (`sweep animation`) mượt mà với đường cong `Curves.easeOutCubic`.
  - Bo tròn đầu cung (`StrokeCap.round`) và khe hở mỹ thuật giữa các lát cắt.
  - **Tương tác chạm (Hit Testing)**: Tính toán góc lượng giác `atan2(dy, dx)` khi người dùng chạm vào biểu đồ để phóng to lát cắt được chọn (`exploded offset`), kích hoạt bóng đổ và hiển thị chi tiết tên, số tiền, tỷ lệ phần trăm ngay tâm biểu đồ.
  - Chú thích danh mục (Legend) dạng viên thuốc có thể chạm để chọn.
- **Animated Weekly Spending Bar Chart (`AnimatedBarChart`)**:
  - Hiệu ứng cột mọc từ dưới lên (0 đến chiều cao thực tế) theo tiến trình hoạt họa.
  - Đỉnh cột bo tròn tinh tế (`Radius.circular(6)`) với dải màu Gradient hiện đại.
  - Lưới tọa độ ngang (Horizontal gridlines) và nhãn trục Y định dạng tiền tệ rút gọn (`0`, `50k`, `100k`, `200k`).
  - Đường nét đứt thể hiện mức chi tiêu trung bình ngày (**Average Line**).
  - **Interactive Tooltip**: Khi chạm vào bất kỳ cột nào, một bong bóng tooltip màu đen với mũi tên chỉ báo sẽ vẽ trực tiếp lên Canvas hiển thị chính xác số tiền `VND` và thứ trong tuần.

---

## 📂 Cấu trúc thư mục dự án (Project Architecture)

```
Project 3/
├── android/
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── AndroidManifest.xml   # Cấu hình Camera, Storage & ML Kit OCR
│   │   │   └── kotlin/.../MainActivity.kt
│   │   └── build.gradle              # minSdkVersion 21, targetSdkVersion 34
│   ├── build.gradle
│   └── settings.gradle
├── ios/
│   └── Runner/Info.plist             # Cấu hình quyền Camera & Photos
├── assets/
│   └── sample_receipts/              # Hóa đơn mẫu (WinMart, Highlands, Fahasa, Grab, CellphoneS)
├── lib/
│   ├── main.dart                     # Khởi tạo Flutter App & Theme
│   ├── models/
│   │   ├── category.dart             # Enum 5 danh mục, màu sắc, icon, tên tiếng Việt
│   │   ├── expense.dart              # Model ExpenseItem & SQLite serialization
│   │   └── parsed_receipt.dart       # Model kết quả bóc tách OCR & Line items
│   ├── services/
│   │   ├── database_helper.dart      # SQLite service (CRUD, lọc, nhóm số liệu biểu đồ)
│   │   ├── ocr_service.dart          # Tích hợp Google ML Kit Text Recognition
│   │   ├── receipt_heuristic_parser.dart # Bộ máy Heuristic Regex tiếng Việt & quốc tế
│   │   └── thumbnail_service.dart    # Cache ảnh hóa đơn & tạo thumbnail
│   ├── widgets/
│   │   ├── animated_donut_chart.dart # CustomPainter biểu đồ tròn tương tác
│   │   ├── animated_bar_chart.dart   # CustomPainter biểu đồ cột tuần tương tác
│   │   ├── framing_crop_overlay.dart # CustomPainter kính ngắm scanner 4 góc
│   │   ├── expense_list_tile.dart    # Thẻ giao dịch hỗ trợ vuốt xóa
│   │   ├── summary_card.dart         # Thẻ gradient tổng quan chi tiêu
│   │   └── category_badge.dart       # Huy hiệu danh mục hiển thị
│   ├── screens/
│   │   ├── home_screen.dart          # Màn hình chính (Danh sách, Tìm kiếm, Lọc)
│   │   ├── camera_screen.dart        # Màn hình Camera Viewfinder & Lấy nét
│   │   ├── receipt_review_screen.dart# Màn hình Xem lại & Sửa kết quả OCR
│   │   ├── analytics_screen.dart     # Dashboard báo cáo tài chính CustomPainter
│   │   └── expense_detail_screen.dart# Xem chi tiết giao dịch & ảnh hóa đơn
│   ├── theme/
│   │   └── app_theme.dart            # Material 3 Design Theme
│   └── utils/
│       └── currency_formatter.dart   # Tiện ích định dạng tiền tệ VND & Parser
├── test/
│   └── receipt_heuristic_parser_test.dart # Bộ kiểm thử tự động cho Parser
└── pubspec.yaml
```

---

## 🛠️ Hướng dẫn cài đặt & Khởi chạy (How to Run)

### Yêu cầu tiên quyết:
- Flutter SDK 3.10+ & Dart 3+
- Thiết bị thật Android (khuyến nghị để test Camera & Google ML Kit) hoặc Android Emulator / iOS Simulator.

### Các bước thực hiện:

1. **Di chuyển vào thư mục dự án**:
   ```bash
   cd "d:\code\Lap Trinh Da Nen Tang\Project 3"
   ```

2. **Cài đặt các gói phụ thuộc (Dependencies)**:
   ```bash
   flutter pub get
   ```

3. **Chạy kiểm thử Heuristic Regex (Unit Tests)**:
   ```bash
   flutter test test/receipt_heuristic_parser_test.dart
   ```
   *(Tất cả 5/5 test case mẫu hóa đơn Việt Nam đều vượt qua 100%)*

4. **Khởi chạy ứng dụng**:
   - Chạy trên thiết bị kết nối:
     ```bash
     flutter run
     ```
   - Chạy bản Release để có hiệu năng cao nhất:
     ```bash
     flutter run --release
     ```

---

## 🧪 Hướng dẫn Demo & Đánh giá (Testing & Evaluation Guide)

1. **Trải nghiệm ngay không cần hóa đơn giấy thật:**
   - Mở ứng dụng -> Nhấn nút **"Scan OCR"** ở giữa thanh điều hướng.
   - Nhấn vào biểu tượng menu hóa đơn góc trên cùng bên phải.
   - Chọn một trong các mẫu hóa đơn có sẵn:
     - 🛒 **WinMart Supermarket**: Nhận diện đúng danh mục `Food`, tổng tiền `215.000 VND`, ngày `12/10/2026`, tự động loại trừ tiền thừa `285.000 VND`.
     - ☕ **Highlands Coffee**: Nhận diện đúng tổng tiền `149.000 đ`, ngày `11/10/2026`, loại trừ tiền thối `51.000 đ`.
     - 📚 **Fahasa Bookstore**: Nhận diện danh mục `Study`, tổng tiền `290.000 VND`, ngày `10/10/2026`.
     - 🛵 **GrabBike Commute**: Nhận diện danh mục `Travel`, tổng tiền `45.000 VND`.
2. **Chụp hóa đơn thật qua Camera:**
   - Đưa hóa đơn vào khung kính ngắm `FramingCropOverlay`.
   - Bật/tắt đèn Flash hoặc chạm vào chữ trên hóa đơn để tự động lấy nét.
   - Bấm nút chụp -> Hệ thống crop ảnh và Google ML Kit xử lý dưới 100ms.
3. **Màn hình Review:**
   - Xem thanh điểm tin cậy `ML Kit AI %`.
   - Bật biểu tượng `</>` để xem mã OCR thô và nhật ký bóc tách.
   - Chỉnh sửa thông tin nếu muốn và bấm **"Save Expense"**.
4. **Màn hình Analytics (CustomPainter):**
   - Chuyển sang tab **"Analytics"**.
   - Quan sát hiệu ứng hoạt họa của biểu đồ Donut và biểu đồ Bar.
   - Chạm vào từng múi biểu đồ tròn để xem tỷ lệ % và số tiền tương ứng.
   - Chạm vào các cột trong tuần để xem Tooltip hiển thị số tiền chính xác.
