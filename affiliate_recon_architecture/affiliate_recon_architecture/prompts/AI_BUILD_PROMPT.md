# Prompt giao AI Coding Assistant xây dựng hệ thống

Bạn là Senior Software Architect và Senior Full-stack Engineer. Hãy xây dựng một web MIS cho Kênh TikTok Phúc Long Mart theo tài liệu `docs/ARCHITECTURE.md`, `docs/EXCEL_FIELD_MAPPING.md` và `database/schema.sql`.

## 1. Mục tiêu

Web phải nhận dữ liệu từ Enterprise API (hoặc Mock Connector khi chưa có API contract), lưu raw artifact, chuẩn hóa dữ liệu Affiliate Orders, quản lý đơn/order items, theo dõi trạng thái thanh toán/giao nhận/hoàn trả riêng với trạng thái quyết toán hoa hồng, chạy đối soát hoa hồng dựa trên dữ liệu nguồn TikTok/doanh nghiệp và tạo KPI/report.

## 2. Các ràng buộc không được vi phạm

1. KHÔNG xây dựng chức năng đối chiếu sao kê ngân hàng.
2. KHÔNG có bảng, API, màn hình hoặc trường `bank_transactions`, `bank_statement`, `bank_received_amount`, `bank_match`.
3. KHÔNG gọi `final_commission_amount_source` là tiền ngân hàng thực nhận. Đây là số tiền cuối theo báo cáo Affiliate.
4. KHÔNG tự suy luận Delivered/Cancelled/Paid từ commission settlement status.
5. Nếu API không có payment/delivery/cancel/refund fields thì dashboard phải hiển thị `Chưa có dữ liệu nguồn`; không bịa KPI.
6. Không tự tạo endpoint, token flow, signature logic hoặc JSON schema cho Enterprise API. Dùng interface/adapter và `MockEnterpriseConnector` cho tới khi có tài liệu thật.
7. Dùng PostgreSQL, không dùng SQLite.
8. Dữ liệu TikTok Order ID/SKU ID/Product ID/Content ID phải là string.
9. Đếm đơn theo distinct order ID; file nguồn có nhiều dòng SKU cho một order.
10. Giữ raw payload/file bất biến; mọi chỉnh sửa normalized data phải có audit trail.
11. Dùng mock data do nhóm generate; không dùng dòng dữ liệu thực của doanh nghiệp làm seed demo.
12. Mọi secret chỉ nằm trong `.env`/secret storage; `.env` không commit, chỉ commit `.env.example`.

## 3. Tech stack

- Frontend: React + TypeScript + Vite.
- Backend: Python + FastAPI.
- Database: PostgreSQL.
- ORM: SQLAlchemy 2.
- Migration: Alembic.
- Excel parser ở backend.
- Docker Compose để chạy local.

## 4. Hãy triển khai tuần tự, không sinh toàn bộ code một lần

### Phase 1 – Project foundation

- Tạo cấu trúc frontend/backend/database.
- Tạo Docker Compose PostgreSQL + backend + frontend.
- Health endpoints.
- `.env.example`, README setup.
- Tạo schema và migration.

### Phase 2 – Data ingestion/ETL

- Tạo connector interface: `EnterpriseAffiliateConnector`.
- Tạo `MockEnterpriseAffiliateConnector` tạo dữ liệu giả lập gần giống 48 cột trong mapping document.
- Cho phép nhận JSON và file XLSX/CSV ở parser layer.
- Tạo import batch, raw file storage, raw records.
- Parse số VND, tỷ lệ %, ngày dd/MM/yyyy HH:mm:ss, slash/blank/null.
- Validate required fields, unknown statuses, duplicates.
- Upsert orders và order items idempotently.
- Tạo endpoint tải raw file.

### Phase 3 – Domain features

- CRUD orders, order items, content references.
- Lưu payment status, fulfillment status, refund status, commission settlement status thành các trường riêng.
- Lưu commission snapshots.
- Lưu order status snapshots/history.
- Tạo reconciliation run và reconciliation items.
- Đối soát các thành phần hoa hồng so sánh cùng cơ sở; không đối chiếu bank.

### Phase 4 – UI

Tạo các màn hình:
1. Dashboard KPI.
2. Kết nối API và trạng thái đồng bộ.
3. Lịch sử batch và tải dữ liệu thô.
4. Dữ liệu đã chuẩn hóa/đơn hàng.
5. Đối soát hoa hồng.
6. Ngoại lệ dữ liệu.
7. Nội dung Video/Live/Showcase.
8. Báo cáo quản trị và export.
9. Quản lý người dùng/roles.

Tái sử dụng phong cách của `index.html` hiện có nếu phù hợp, nhưng phải thay mọi dữ liệu JS hardcode bằng backend API và loại bỏ tất cả logic ngân hàng.

### Phase 5 – Reporting

Dùng cohort `order_created_at` theo múi giờ Asia/Ho_Chi_Minh.
- Total orders = distinct order_id.
- Paid rate = distinct paid orders / total placed orders.
- Delivered rate = distinct delivered orders / total placed orders.
- Cancel rate = distinct cancelled orders / total placed orders.
- Refund rate = distinct orders with a refund / total placed orders.
- Settled commission rate = distinct orders whose all order items are settled / total placed orders.

Các KPI milestone có thể overlap; UI phải chú thích không cộng lại thành 100%. Không tính Paid/Delivered/Cancelled khi API không có dữ liệu tương ứng.

### Phase 6 – Tests

Viết tests cho:
- 18-digit ID remains string.
- 2.107 SKU rows nhưng tổng order count distinct không bằng row count.
- Multi-SKU order import.
- Duplicate batch/idempotency.
- Locale parse `248.399` to 248399 VND.
- Parse percent `5%` to 5.
- Null `/` does not become 0 automatically.
- Date parse with Vietnam timezone.
- Status mapping and unknown status.
- Payment/delivery/cancel/refund metrics separated from commission settlement.
- Commission comparison does not compare bank transactions.

## 5. Chất lượng bàn giao

- Không để TODO giả vờ như đã tích hợp API thật.
- Có mock mode chạy được end-to-end.
- CRUD thực sự lưu vào PostgreSQL.
- Có ít nhất 50 bản ghi mock để dashboard có ý nghĩa.
- Có export CSV/XLSX từ dữ liệu database.
- Có test suite và README từng bước chạy.
- Ghi requirement ID/feature mapping.
- Tất cả endpoint có validation, error handling và logging.
- Mỗi phase sau khi code xong phải báo file thay đổi, cách chạy, cách test và giới hạn chưa xác minh.

Trước khi code, hãy đọc toàn bộ tài liệu kiến trúc. Sau đó chỉ thực hiện Phase 1, trình bày cấu trúc và test cho tôi review; không chuyển sang phase tiếp theo cho đến khi tôi yêu cầu.
