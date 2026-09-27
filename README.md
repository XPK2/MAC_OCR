# MacOCR

App macOS native (AppKit, MVC) để OCR ảnh/PDF bằng Apple Vision rồi xuất ra Markdown — hoàn toàn on-device, không thư viện OCR hay API cloud bên thứ ba.

## Cài lên máy Mac khác (không cần build)

Yêu cầu: **macOS 14+**, Apple Silicon hoặc Intel (binary universal). Không cần cài thêm gì — Vision, PDFKit và Swift runtime có sẵn trong macOS.

1. Copy `dist/MacOCR-<version>.dmg` sang máy đích, mở file DMG.
2. Chọn một trong hai:
   - Double-click **Install MacOCR.command** → tự copy vào `/Applications` (hoặc `~/Applications` nếu không có quyền), gỡ cờ quarantine và mở app.
   - Hoặc kéo **MacOCR.app** vào **Applications** như app thường.
3. App chỉ ký ad-hoc (chưa notarize) nên nếu macOS chặn:
   - Script `.command` bị chặn → chạy trong Terminal: `bash "/Volumes/MacOCR/Install MacOCR.command"`
   - App bị chặn → **System Settings › Privacy & Security › Open Anyway**, hoặc `xattr -dr com.apple.quarantine /Applications/MacOCR.app`

> Lần OCR **đầu tiên** trên mỗi máy có thể mất vài chục giây: macOS biên dịch model OCR cho Neural Engine (`ANECompilerService`). Các lần sau nhanh.

## Build từ source

```bash
./scripts/install.sh        # build + cài vào /Applications (tự tải Xcode Command Line Tools nếu thiếu)
./scripts/make-app.sh       # chỉ build → build/MacOCR.app, dist/MacOCR-<ver>.dmg, dist/MacOCR-<ver>.zip
./scripts/test.sh           # unit test (Swift Testing)
swift run MacOCR            # chạy thử không đóng gói
VERSION=1.1 ./scripts/make-app.sh
```

Không có Swift toolchain → script tự gọi `xcode-select --install` và đợi cài xong rồi chạy tiếp. Không cần Xcode đầy đủ.

## Cách dùng

1. **Open…** (⌘O), kéo-thả vào ô bên trái, kéo vào icon trên Dock, hoặc Finder › *Open With › MacOCR*. Hỗ trợ mọi định dạng ảnh ImageIO đọc được (png, jpg, heic, tiff, gif, bmp, webp…) và PDF nhiều trang; chọn nhiều file cùng lúc được.
2. Popup ngôn ngữ lấy danh sách thật từ Vision trên máy đang chạy; mặc định **Automatic**.
3. Tiến độ theo trang ở thanh dưới, **Cancel** để huỷ. File lỗi được bỏ qua và báo cuối, không làm hỏng cả batch.
4. Kết quả markdown ở panel phải — **sửa tay được** (có Undo ⌘Z) trước khi xuất.
5. **Mark low confidence**: bọc `<mark>` quanh dòng có độ tin cậy < 0.5 (bật/tắt sẽ render lại, ghi đè chỗ đã sửa tay).
6. **Copy** hoặc **Export .md** (⌘S). Nhiều file: gộp 1 `.md` (lấy nội dung đang hiển thị) hoặc mỗi file 1 `.md` (render lại từ kết quả OCR).

PDF đã có text layer → lấy text trực tiếp, không OCR. PDF scan → render từng trang 300 DPI grayscale (tôn trọng xoay trang), chỉ giữ 1 trang trong RAM. Ảnh chụp điện thoại → tôn trọng EXIF orientation.

## Kiến trúc

```
Sources/MacOCR/
├── Model/        # không import AppKit: DocumentLoader, OCRService, MarkdownExporter, OCR{Document,Page,Line}
├── View/         # MainView, DropZoneView — chỉ hiển thị, đẩy sự kiện lên Controller
├── Controller/   # MainWindowController, MainViewController — load → OCR (off main thread) → preview → export
├── AppDelegate.swift, main.swift
scripts/          # make-app.sh, install.sh, test.sh, ensure-toolchain.sh
```

## Giới hạn đã biết

- Không nhận dạng bảng/layout nhiều cột thành Markdown table; cột có thể bị xen dòng.
- Không tối ưu cho chữ viết tay.
- GIF/TIFF nhiều frame: chỉ frame đầu.
- Chưa có icon riêng, chưa notarize (cần Apple Developer ID).
