# Cách hoạt động

[← README](../README.md) | [English](how-it-works.md)

## Memory được lưu ở đâu

Claude Code lưu memory **theo từng dự án**, bên ngoài repo, trong thư mục home của bạn:

```text
~/.claude/projects/
└── -home-you-workspace-myapp/          ← đường dẫn dự án, "/" và "." đổi thành "-"
    └── memory/
        ├── MEMORY.md                   ← INDEX: nạp vào MỌI phiên (giữ nhỏ!)
        ├── feedback-test-on-staging.md ← mỗi memory là 1 file, có frontmatter
        ├── reference-stg-access.md
        └── project-epic-123.md
```

- Memory chỉ nằm trên máy bạn, không commit, không chia sẻ cho team.
- `MEMORY.md` là mục lục: mỗi dòng gồm tiêu đề, link tới file và một câu tóm tắt.
  Claude đọc mục lục ở mỗi phiên, còn nội dung file chỉ mở khi cần.
- Plugin cài vào `~/.claude/plugins/` (dùng chung mọi dự án) và tự tìm thư mục memory theo thư mục đang mở.

Memory chỉ là **một trong nhiều nơi** lưu kiến thức. Kiến thức nào cũng nên về chỗ bền nhất của nó:

```mermaid
flowchart LR
    N["Điều mới học được"] --> Q{"Nó là gì?"}
    Q -->|"Luật luôn áp dụng cho repo"| R["AGENTS.md / rules<br/>(commit, cả team dùng)"]
    Q -->|"Cách làm một loại việc"| S["Skill<br/>(nạp khi cần)"]
    Q -->|"Bài học, lỗi hay gặp"| K["docs/knowledge<br/>(commit)"]
    Q -->|"Sở thích của bạn, ngữ cảnh đang làm,<br/>link ngoài, luật chưa ổn định"| M["Memory<br/>(chỉ trên máy bạn)"]
    M -. "ổn định rồi → promote" .-> R
    M -. "thành bài học → promote" .-> K
```

## Cách hoạt động

### Vòng đời một memory

```mermaid
stateDiagram-v2
    [*] --> active: Claude ghi memory<br/>(plugin điền source, verified, status)
    active --> active: xác minh lại → cập nhật verified
    active --> superseded: có fact mới thay thế,<br/>hoặc đã chuyển lên rules / skill / docs
    active --> done: work item xong, không còn bài học
    superseded --> [*]: giữ trên đĩa làm lịch sử,<br/>không còn trong MEMORY.md
    done --> [*]
```

Mỗi file memory có một ít metadata:

```yaml
metadata:
  type: user | feedback | project | reference
  source: user | agent      # điều bạn nói thì Claude không tự ý sửa
  verified: 2026-10-29      # lần cuối đối chiếu với code / tracker
  status: active | superseded | done
```

Chỉ memory `active` có mặt trong `MEMORY.md`.

### Mỗi lần mở phiên

```mermaid
flowchart TD
    A(["Mở Claude Code trong dự án"]) --> B{"Có thư mục memory?"}
    B -->|không| Z(["Im lặng"])
    B -->|có| C["1. Điền metadata cho file mới<br/>(memory-migrate.py)"]
    C --> D["2. Dựng lại MEMORY.md nếu lệch<br/>(memory-index.py)"]
    D --> E["3. Audit<br/>(memory-audit.sh)"]
    E --> F{"Có việc cần phán đoán?"}
    F -->|không| Z
    F -->|có| G["In 1 dòng:<br/>Memory upkeep due: stale=… code-changed=…"]
    G --> H["Khi rảnh: /memory-hygiene:clean<br/>→ Claude xác minh, đề xuất, bạn duyệt"]
    classDef auto fill:#e6f4ea,stroke:#34a853
    class C,D,E auto
```

Kết quả audit được cache cho tới khi memory, git HEAD hoặc ngày thay đổi, nên mở phiên gần như tức thì.
Ngoài ra, mỗi lần Claude mở một file memory, hook ghi lại vào `memory/.usage.log` để biết memory nào thật sự được dùng.

Bước 1–3 (màu xanh) chạy tự động và luôn cho cùng một kết quả. Plugin **không bao giờ tự sửa nội dung**
của memory: phần đó cần phán đoán nên để Claude đề xuất và bạn duyệt.

### Audit kiểm tra gì

| Dấu hiệu | Nghĩa là | Xử lý |
|---|---|---|
| **stale** | quá 45 ngày chưa xác minh | đối chiếu lại, cập nhật `verified` |
| **code changed** | file mà memory nhắc tới có commit sau ngày `verified` (git) | đọc lại diff, sửa hoặc xác nhận |
| **broken path** | đường dẫn trong repo không còn | sửa đường dẫn |
| **over budget** | index > 8 KB, > 45 mục, hoặc dòng > 200 ký tự | rút gọn, promote, supersede |
| **promote candidates** | luật của bạn ổn định > 30 ngày | chuyển lên rules của dự án |
| **unused** | 60 ngày không được mở (theo dõi bằng hook) | bỏ khỏi index hoặc supersede |
| **related pairs** | hai memory có nhiều từ chung, có thể trùng | đọc cả hai, gộp nếu nói cùng một điều |

Ba dòng cuối chỉ hiện trong báo cáo `/memory-hygiene:audit`, không làm hiện dòng nhắc đầu phiên.
`unused` chỉ bắt đầu báo sau khi đã theo dõi đủ 60 ngày.

Ví dụ thật: một memory nói "tối ưu Dockerfile đang chờ làm" và nhắc tới `backend/docker/Production.Dockerfile`.
File đó có 2 commit sau ngày `verified`, nên audit báo **code changed**. Claude kiểm tra và thấy PR đã merge,
rồi cập nhật memory. Không có cơ chế này, phiên sau vẫn tin rằng việc còn đang chờ.

## Thiết kế: vì sao hiệu quả

1. **Index nhỏ, luôn được nạp.** Chỉ những gì cần ở *mọi* phiên mới nằm trong `MEMORY.md`;
   phần còn lại chỉ mở khi cần.
2. **Memory là chỗ tạm.** Luật ổn định chuyển lên `AGENTS.md` / rules, kỹ thuật chuyển vào skill,
   bài học chuyển vào docs. Memory chỉ giữ những gì chưa có chỗ tốt hơn.
3. **Thay thế, không ghi đè.** Thông tin cũ được giữ làm lịch sử; điều bạn nói thắng điều Claude suy luận.
4. **Tự động phần chắc chắn, nhắc phần cần phán đoán.** Script không bao giờ đổi ý nghĩa của một memory.
5. **Kiểm tra độ cũ bằng git, không cần knowledge graph.** Vài chục file không cần graph;
   "code được nhắc tới đã đổi sau ngày xác minh" là tín hiệu chính xác nhất.

Hướng dẫn đầy đủ (tiếng Anh): [`docs/memory-system.md`](memory-system.md).

## Cấu hình (biến môi trường, không bắt buộc)

| Biến | Mặc định |
|---|---|
| `MEMORY_INDEX_MAX_BYTES` | 8000 |
| `MEMORY_INDEX_MAX_ENTRIES` | 45 |
| `MEMORY_INDEX_MAX_LINE` | 200 |
| `MEMORY_UNUSED_DAYS` | 60 |
| `MEMORY_DUP_THRESHOLD` | 0.4 |
| `MEMORY_HYGIENE_NO_CACHE` | (đặt bất kỳ giá trị nào để tắt cache) |
| `MEMORY_HYGIENE_DIR` | thư mục memory suy ra từ thư mục đang mở |

## Lệnh chạy tay

```bash
python3 scripts/memory-migrate.py [memory_dir]                 # thêm metadata (chạy lại nhiều lần không sao)
python3 scripts/memory-index.py   [memory_dir] [--check]       # dựng lại / kiểm tra MEMORY.md
bash    scripts/memory-audit.sh   [memory_dir] [repo] [days]   # báo cáo đầy đủ, không sửa gì
```

Cần bash, Python 3 (`python3`, `python` hoặc `py`), git. Trên Windows dùng Git Bash, thứ Claude Code vốn đã yêu cầu. CI chạy `tests/run.sh` trên Linux, macOS và Windows.

