# memory-hygiene

**Tiếng Việt** | [English](README.en.md)

Plugin cho Claude Code giúp auto-memory luôn **gọn, đúng và đáng tin**, dùng được cho mọi dự án.

Claude Code tự ghi memory vào `~/.claude/projects/<project>/memory/`. Để lâu sẽ phình ra:
thông tin cũ, trùng lặp, đường dẫn không còn tồn tại, và một file index bị nạp vào *mọi* phiên làm việc.
Plugin này giữ mọi thứ gọn gàng mà bạn gần như không phải làm gì.

## Bắt đầu nhanh

```text
/plugin marketplace add nhim411/claude-memory-hygiene
/plugin install memory-hygiene@nhim411-memory-hygiene
```

Khởi động lại Claude Code, rồi trong mỗi dự án nói một lần:

> migrate memory

Vậy là xong. Từ đó về sau:

| Bạn | Plugin |
|---|---|
| làm việc bình thường | mỗi lần mở phiên tự sửa index và điền metadata còn thiếu, không làm phiền |
| thấy dòng `Memory upkeep due: …` | không bắt buộc làm gì; rảnh thì xử lý |
| nói **"dọn memory"** / **"clean up memory"** | kiểm tra, xác minh lại thông tin cũ, đề xuất thay đổi, dựng lại index |
| nói **"nhớ giúp …"** / **"remember …"** | lưu lại với đúng loại, nguồn và ngày |

## Cách hoạt động

```
mở phiên ─► điền metadata thiếu ─► dựng lại MEMORY.md ─► audit ─► nhắc 1 dòng (chỉ khi cần)
                 (tự động, kết quả luôn giống nhau)                 (bạn / Claude quyết định)
```

Mỗi file memory có một ít metadata:

```yaml
metadata:
  type: user | feedback | project | reference
  source: user | agent      # điều bạn nói thì Claude không tự ý sửa
  verified: 2026-10-29      # lần cuối đối chiếu với code / tracker
  status: active | superseded | done
```

Chỉ memory `active` xuất hiện trong `MEMORY.md`. File `superseded` / `done` vẫn giữ trên đĩa làm lịch sử.

Audit phát hiện:

- **stale**: quá 45 ngày chưa xác minh
- **code changed**: file mà memory nhắc tới có commit mới sau ngày `verified` (dùng git)
- **broken path**: đường dẫn trong repo không còn tồn tại
- **over budget**: index > 8 KB, > 45 mục, hoặc có dòng > 200 ký tự
- **promote candidates**: luật của bạn đã ổn định một tháng, nên chuyển vào rules của dự án

## Thiết kế: vì sao hiệu quả

1. **Index nhỏ, luôn được nạp.** Chỉ những gì cần ở *mọi* phiên mới nằm trong `MEMORY.md`;
   phần còn lại chỉ mở khi cần.
2. **Memory là chỗ tạm.** Luật ổn định chuyển lên `AGENTS.md` / rules, kỹ thuật chuyển vào skill,
   bài học chuyển vào docs. Memory chỉ giữ những gì chưa có chỗ tốt hơn.
3. **Thay thế, không ghi đè.** Thông tin cũ được giữ làm lịch sử; điều bạn nói thắng điều Claude suy luận.
4. **Tự động phần chắc chắn, nhắc phần cần phán đoán.** Script không bao giờ đổi ý nghĩa của một memory.
5. **Kiểm tra độ cũ bằng git, không cần knowledge graph.** Vài chục file không cần graph;
   "code được nhắc tới đã đổi sau ngày xác minh" là tín hiệu chính xác nhất.

Hướng dẫn đầy đủ (tiếng Anh): [`docs/memory-system.md`](docs/memory-system.md).

## Cấu hình (biến môi trường, không bắt buộc)

| Biến | Mặc định |
|---|---|
| `MEMORY_INDEX_MAX_BYTES` | 8000 |
| `MEMORY_INDEX_MAX_ENTRIES` | 45 |
| `MEMORY_INDEX_MAX_LINE` | 200 |
| `MEMORY_HYGIENE_DIR` | thư mục memory suy ra từ thư mục đang mở |

## Lệnh chạy tay

```bash
python3 scripts/memory-migrate.py [memory_dir]                 # thêm metadata (chạy lại nhiều lần không sao)
python3 scripts/memory-index.py   [memory_dir] [--check]       # dựng lại / kiểm tra MEMORY.md
bash    scripts/memory-audit.sh   [memory_dir] [repo] [days]   # báo cáo đầy đủ, không sửa gì
```

Cần bash, python3, git, GNU `date`. Đã test trên Linux / WSL.

## Giấy phép

MIT
