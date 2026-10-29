# 🧠 memory-hygiene

**Tiếng Việt** | [English](README.en.md)

[![test](https://github.com/nhim411/claude-memory-hygiene/actions/workflows/test.yml/badge.svg)](https://github.com/nhim411/claude-memory-hygiene/actions/workflows/test.yml)
![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-d97757)
![License: MIT](https://img.shields.io/badge/license-MIT-blue)

Plugin Claude Code giữ auto-memory **gọn, đúng và đáng tin**: tự dọn, tự phát hiện ghi nhớ đã lỗi thời.

## Cài đặt

Chạy 2 lệnh trong Claude Code, rồi khởi động lại:

```text
/plugin marketplace add nhim411/claude-memory-hygiene
/plugin install memory-hygiene@nhim411-memory-hygiene
```

Xong. Không cần cấu hình. Chạy trên Linux, macOS và Windows.

## Sử dụng

Làm việc như bình thường. Mỗi lần mở phiên, plugin tự sửa index và chỉ nhắc một dòng khi có việc cần làm.

| Lệnh | Tác dụng |
|---|---|
| `/memory-hygiene:clean` | dọn memory: Claude xác minh, đề xuất kèm bằng chứng, bạn duyệt |
| `/memory-hygiene:audit` | xem báo cáo, không sửa gì |
| `/memory-hygiene:promote` | chuyển luật bạn hay dặn thành rules của dự án |

## Vì sao cần

Auto-memory của Claude Code chỉ ghi thêm, không tự dọn. Lâu dần mỗi phiên phải nạp những ghi chú cũ,
trùng lặp, và Claude có thể làm theo một "sự thật" đã sai.

Kết quả trên một dự án thật:

| | Trước | Sau |
|---|---|---|
| Index nạp vào mọi phiên | 60 mục, 11.8 KB | **40 mục, 7.0 KB** |
| Memory có nguồn + ngày xác minh | 0% | **100%** |
| Ghi nhớ sai được phát hiện | — | route đã đổi, PR đã merge vẫn ghi "đang chờ" |

## Tính năng

- 🔍 **Phát hiện ghi nhớ lỗi thời**: báo khi code mà memory nhắc tới có commit mới.
- 🧹 **Tự sửa phần chắc chắn, hỏi phần cần phán đoán.**
- 🛡️ **Không tự sửa điều bạn đã dặn.**
- 📉 **Index luôn nhỏ**: giới hạn kích thước, báo memory không ai đọc.
- ⚡ **Nhẹ**: bash + Python 3 + git, không database, không gọi mạng.

📖 Chi tiết: [Cách hoạt động](docs/how-it-works.vi.md) · [Hướng dẫn memory](docs/memory-system.md)

## Giấy phép

MIT
