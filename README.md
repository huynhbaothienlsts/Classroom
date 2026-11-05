# LabFlow — Quản lý hoạt động nhóm trong phòng máy

LabFlow là ứng dụng React + Supabase dành cho giáo viên tổ chức hoạt động nhóm theo thời gian thực.

## Tính năng hiện có

- Đăng ký và đăng nhập giáo viên bằng Supabase Auth.
- Trình thiết lập lớp, số nhóm, danh sách học sinh và nhiều hoạt động.
- Tự gán học sinh vào nhóm bằng mã số; học sinh không tự chọn nhóm khác.
- Nộp nội dung, URL hoặc tệp lên Supabase Storage.
- Chỉ mở khóa nút chuông sau khi backend xác nhận bài nộp.
- Xếp hạng bằng thời gian PostgreSQL, có ràng buộc mỗi nhóm một lượt mỗi vòng.
- Dashboard giáo viên, sơ đồ nhóm, bài nộp, thứ tự chuông và Realtime.
- Cấu trúc dữ liệu cho tiêu chí, đánh giá chéo, điểm và nhật ký.
- Giao diện responsive cho máy tính và điện thoại.
- Chế độ xem thử tự động khi chưa cấu hình Supabase.

Các tệp `dashboard.html`, `student.html`, `schema.sql`, `config.js` và `firebase-config.js` ở thư mục gốc là phiên bản mẫu cũ, chỉ được giữ để tham khảo. Ứng dụng mới nằm trong `src/` và `supabase/`.

## Chạy trên máy

Yêu cầu Node.js 18 trở lên.

```bash
npm install
npm run dev
```

Mở `http://127.0.0.1:4173`.

Nếu chưa cấu hình Supabase, website chạy bằng dữ liệu minh họa để xem giao diện.

## Thiết lập Supabase

1. Tạo project mới tại https://supabase.com/dashboard.
2. Mở **SQL Editor → New query**.
3. Sao chép toàn bộ nội dung `supabase/schema.sql`, dán vào và chọn **Run**.
4. Mở **Authentication → Providers → Anonymous Sign-Ins** và bật tính năng này. Học sinh sử dụng phiên ẩn danh; giáo viên vẫn đăng nhập email/mật khẩu.
5. Trong **Authentication → URL Configuration**, thêm URL GitHub Pages vào Redirect URLs, ví dụ:
   `https://TEN_GITHUB.github.io/TEN_REPOSITORY/**`
6. Vào **Project Settings → API** và sao chép:
   - Project URL
   - Publishable/anon key
7. Mở `public/config.js`, thay hai giá trị mẫu bằng URL và anon key.

Anon key được phép xuất hiện ở frontend. Không bao giờ đưa `service_role` key vào repository.

## Luồng sử dụng đầu tiên

1. Giáo viên mở `/#/teacher`, chọn **Đăng ký** và tạo tài khoản.
2. Vào **Lớp & nhóm** để mở trình thiết lập.
3. Nhập danh sách theo định dạng `Mã số,Họ tên`, mỗi học sinh một dòng.
4. Khai báo số nhóm, tên buổi, mã tham gia và các hoạt động.
5. Chọn **Tạo và mở buổi học**.
6. Học sinh mở `/#/student`, nhập mã buổi và mã số học sinh.
7. Supabase tự xác định nhóm từ danh sách phân công.

## Build

```bash
npm run build
```

Website tĩnh được tạo trong `dist/`. Tệp `404.html` được sinh để các đường dẫn của ứng dụng hoạt động trên GitHub Pages.

## Deploy GitHub Pages thủ công

1. Tạo repository mới trên GitHub.
2. Đưa toàn bộ thư mục dự án lên nhánh `main`.
3. Mở **Settings → Secrets and variables → Actions**.
4. Tạo hai repository secrets:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
5. Mở **Settings → Pages**.
6. Tại **Build and deployment → Source**, chọn **GitHub Actions**.
7. Đẩy một commit mới hoặc chạy workflow **Deploy LabFlow to GitHub Pages** trong tab Actions.

Workflow `.github/workflows/pages.yml` sẽ tự cài thư viện, tạo cấu hình Supabase, build và xuất bản website.

## Bảo mật

- RLS được bật cho toàn bộ bảng nghiệp vụ.
- Nhóm được suy ra từ phiên tham gia, không tin `group_id` do trình duyệt gửi.
- Nộp bài và bấm chuông chạy qua PostgreSQL RPC `security definer`.
- Thời gian chuông dùng `clock_timestamp()` của cơ sở dữ liệu.
- Tệp nằm trong bucket riêng tư `submissions`.
- Mọi thao tác tham gia, nộp bài và bấm chuông đều được ghi vào `audit_logs`.

Trước khi dùng chính thức, nên thử nghiệm với một lớp nhỏ và kiểm tra chính sách lưu trữ dữ liệu học sinh của nhà trường.
