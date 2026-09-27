# PROMPT: Build macOS OCR → Markdown App (MVC, Apple Vision)

> Giao cho AI coding agent. Đọc hết trước khi code. Chỗ nào không rõ → hỏi lại, không tự đoán.

## 1. Mục tiêu

Xây app **macOS native** (chỉ chạy trên Mac) có giao diện, cho phép người dùng:

1. Chọn / kéo-thả file (ảnh hoặc PDF).
2. Chạy OCR bằng **framework có sẵn của Apple (Vision)** — không dùng thư viện OCR bên thứ 3, không gọi API cloud.
3. Xem trước kết quả text.
4. Xuất kết quả ra file **`.md`**.

## 2. Ràng buộc bắt buộc

| Mục | Yêu cầu |
|---|---|
| Ngôn ngữ | Swift 6 (toolchain hiện có: Swift 6.2) |
| UI | **AppKit** (Cocoa MVC chuẩn: `NSWindowController` / `NSViewController` / `NSView`). Không dùng SwiftUI. |
| OCR | `Vision` (`VNRecognizeTextRequest` hoặc API Swift mới `RecognizeTextRequest` nếu target cho phép) |
| PDF | `PDFKit` (render page → `CGImage`) |
| Dependency | **0 dependency ngoài.** Chỉ Apple SDK. |
| Build | Build được từ CLI bằng `swift build` (Swift Package), kèm script đóng gói `.app` |
| Deployment target | macOS 14+ |
| Offline | 100% on-device |

## 3. Kiến trúc MVC

```
MAC_OCR/
├── Package.swift
├── Sources/MacOCR/
│   ├── main.swift                      # khởi tạo NSApplication + AppDelegate
│   ├── AppDelegate.swift               # tạo window, menu bar
│   ├── Model/
│   │   ├── OCRDocument.swift           # struct: sourceURL, pages: [OCRPage]
│   │   ├── OCRPage.swift               # struct: index, lines: [OCRLine]
│   │   ├── OCRLine.swift               # struct: text, confidence, boundingBox
│   │   ├── OCRService.swift            # Vision: CGImage -> [OCRLine]
│   │   ├── DocumentLoader.swift        # URL -> [CGImage] (ảnh / PDF)
│   │   └── MarkdownExporter.swift      # OCRDocument -> String (markdown)
│   ├── View/
│   │   ├── MainView.swift              # layout: drop zone + text preview + toolbar
│   │   └── DropZoneView.swift          # NSView nhận drag & drop file
│   └── Controller/
│       ├── MainWindowController.swift
│       └── MainViewController.swift    # điều phối: load -> OCR -> preview -> export
├── Tests/MacOCRTests/
│   └── MarkdownExporterTests.swift
└── scripts/
    └── make-app.sh                     # swift build -c release -> MacOCR.app (có Info.plist)
```

**Quy tắc phân tầng (bắt buộc):**
- **Model**: không `import AppKit`. Chỉ `Foundation`, `Vision`, `PDFKit`, `CoreGraphics`. Test được độc lập.
- **View**: chỉ hiển thị + chuyển sự kiện lên Controller (delegate/closure). Không gọi Vision, không đọc file.
- **Controller**: nhận sự kiện từ View, gọi Model, cập nhật View. Toàn bộ OCR chạy **off main thread** (`async/await`), update UI trên `@MainActor`.
- Không tạo protocol/abstraction chỉ có 1 implementation.

## 4. Chức năng chi tiết

### 4.1 Input
- Định dạng: `png`, `jpg/jpeg`, `heic`, `tiff`, `bmp`, `gif` (frame đầu), `pdf` (nhiều trang).
- Cách nhập: nút **Open…** (`NSOpenPanel`, lọc bằng `UTType`), **kéo-thả** vào DropZone, menu **File > Open** (⌘O).
- Hỗ trợ chọn **nhiều file** cùng lúc → mỗi file là 1 section trong markdown.

### 4.2 OCR (Model/OCRService)
- `recognitionLevel = .accurate`, `usesLanguageCorrection = true`.
- Ngôn ngữ: lấy danh sách từ `supportedRecognitionLanguages()` **tại runtime**, hiển thị popup cho user chọn (mặc định: `automaticallyDetectsLanguage = true` nếu có, kèm `en-US`). Không hard-code giả định ngôn ngữ nào được hỗ trợ — tiếng Việt có hay không phải kiểm tra runtime trên máy.
- PDF: với mỗi trang, **nếu `PDFPage.string` có text thật** (PDF có text layer) → dùng luôn, bỏ qua OCR. Ngược lại render trang ở ~300 DPI → OCR.
- Sắp xếp dòng theo thứ tự đọc: `boundingBox` (Vision dùng toạ độ gốc dưới-trái) → sort theo Y giảm dần, rồi X tăng dần.
- Gộp dòng thành đoạn: khoảng cách dọc giữa 2 dòng > ~1.5× chiều cao dòng → xuống đoạn mới.
- Báo tiến độ theo trang (`Progress` hoặc callback `(done, total)`).
- Hỗ trợ **Cancel** (Task cancellation).

### 4.3 Markdown output (Model/MarkdownExporter)
Format:

```markdown
# <tên file gốc>

> OCR bởi Apple Vision · <ngày giờ ISO8601> · Ngôn ngữ: <langs> · Trang: <n>

## Trang 1

<đoạn 1>

<đoạn 2>

---

## Trang 2

...
```

- Ảnh đơn (1 trang) → bỏ heading `## Trang 1`.
- Escape ký tự markdown đặc biệt ở đầu dòng (`#`, `>`, `-`, `*`, `+`, `1.`) để text OCR không vô tình thành heading/list.
- Tuỳ chọn (checkbox trong UI): **"Đánh dấu dòng độ tin cậy thấp"** → dòng có `confidence < 0.5` bọc bằng `<mark>…</mark>`.
- Encoding UTF-8, line ending `\n`.

### 4.4 Export
- Nút **Export .md** (⌘S) → `NSSavePanel`, tên mặc định = `<tên file gốc>.md`, cùng thư mục file gốc.
- Nút **Copy** → copy markdown vào clipboard (`NSPasteboard`).
- Nhiều file input: tuỳ chọn **gộp 1 file .md** hoặc **mỗi file 1 .md** (chọn thư mục đích).

## 5. Giao diện

```
┌──────────────────────────────────────────────────────────┐
│ [Open…] [Language ▾] [☐ Mark low confidence]  [Export] [Copy] │
├───────────────────────┬──────────────────────────────────┤
│                       │                                  │
│   Drop file here      │   Markdown preview               │
│   (hoặc thumbnail     │   (NSTextView, monospace,        │
│    trang đang chọn)   │    cho phép sửa tay trước export)│
│                       │                                  │
├───────────────────────┴──────────────────────────────────┤
│ [████████░░░░] Trang 3/8          [Cancel]     status…   │
└──────────────────────────────────────────────────────────┘
```

- `NSSplitView` 2 cột, cửa sổ resize được, min size 800×500.
- Preview là **editable** — export lấy nội dung đang hiển thị (user sửa lỗi OCR trước khi lưu).
- Hỗ trợ Dark Mode (dùng system colors, không hard-code màu).
- Nút Export/Copy disabled khi chưa có kết quả; Open disabled khi đang OCR.
- Menu bar chuẩn: App (About, Quit ⌘Q), File (Open ⌘O, Export ⌘S), Edit (Copy/Paste/Select All để NSTextView hoạt động).

## 6. Xử lý lỗi

Hiển thị `NSAlert` rõ ràng (không crash) cho:
- File không đọc được / định dạng không hỗ trợ.
- PDF có mật khẩu (`PDFDocument.isLocked`) → báo lỗi, không crash.
- OCR không tìm thấy text → vẫn xuất markdown với dòng `_(Không phát hiện văn bản)_`.
- Ghi file thất bại (quyền, disk full).

## 7. Build & chạy

```bash
swift build                 # debug
swift run MacOCR            # chạy thử
swift test                  # unit test
./scripts/make-app.sh       # -> build/MacOCR.app
open build/MacOCR.app
```

`make-app.sh` phải: build release, tạo cấu trúc `MacOCR.app/Contents/{MacOS,Resources,Info.plist}`, set `CFBundleIdentifier`, `LSMinimumSystemVersion=14.0`, `NSHighResolutionCapable=true`, rồi ad-hoc codesign (`codesign -s - --force --deep`).

## 8. Test tối thiểu

`Tests/MacOCRTests/MarkdownExporterTests.swift`:
- Input 2 trang giả lập → output đúng heading, separator `---`, thứ tự đoạn.
- Dòng bắt đầu bằng `# ` được escape thành `\# `.
- Ảnh 1 trang → không có `## Trang 1`.
- Trang rỗng → có `_(Không phát hiện văn bản)_`.

Thêm 1 test OCR thật: tạo ảnh chứa chữ `"Hello OCR 123"` bằng CoreGraphics trong test → chạy `OCRService` → assert kết quả chứa `Hello`.

## 9. Tiêu chí hoàn thành (Definition of Done)

- [ ] `swift build` và `swift test` pass, không warning concurrency của Swift 6.
- [ ] `make-app.sh` tạo `.app` mở được bằng double-click.
- [ ] Kéo 1 ảnh chụp màn hình vào → thấy markdown trong preview → Export ra `.md` mở được bằng editor bất kỳ.
- [ ] PDF nhiều trang → có progress, cancel được giữa chừng.
- [ ] Model không import AppKit (kiểm bằng `grep -r "import AppKit" Sources/MacOCR/Model` → rỗng).
- [ ] README.md cập nhật: yêu cầu hệ thống, cách build, cách dùng.

## 10. Ngoài phạm vi (KHÔNG làm)

- Nhận dạng bảng / layout phức tạp → Markdown table.
- OCR chữ viết tay có đảm bảo chất lượng.
- Batch folder watcher, CLI mode, sandbox / App Store, auto-update.
- Bất kỳ dependency / SDK bên thứ 3 nào.

## 11. Cách làm việc

1. Đọc prompt → liệt kê câu hỏi nếu có điểm mơ hồ.
2. Dựng skeleton + `Package.swift` → `swift build` pass.
3. Làm Model + test trước (TDD cho `MarkdownExporter`).
4. Làm View + Controller.
5. Script đóng gói, README.
6. Chạy lại toàn bộ Definition of Done, báo cáo kết quả thật (kèm output lệnh), không tuyên bố "xong" khi chưa chạy.
