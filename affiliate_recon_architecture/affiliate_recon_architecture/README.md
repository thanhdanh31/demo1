# TikTok Affiliate Reconciliation – Architecture Starter Pack

Bộ tài liệu kiến trúc để nhóm dùng làm đầu vào cho AI coding assistant xây dựng web MIS.

## Nội dung

- `docs/ARCHITECTURE.md`: kiến trúc nghiệp vụ, kiến trúc hệ thống, luồng ETL/API, KPI và màn hình.
- `docs/EXCEL_FIELD_MAPPING.md`: ánh xạ 48 cột trong workbook Affiliate Orders được cung cấp.
- `database/schema.sql`: schema PostgreSQL khởi đầu, không dùng SQLite.
- `api-contract/ENTERPRISE_API_CONTRACT_TEMPLATE.md`: thông tin cần lấy từ doanh nghiệp trước khi viết connector thật.
- `prompts/AI_BUILD_PROMPT.md`: prompt tổng để giao AI triển khai code theo từng phase.

## Nguyên tắc quan trọng

1. Chưa có tài liệu API thật thì chỉ triển khai `MockEnterpriseConnector`; không tự bịa endpoint, token flow hoặc JSON fields.
2. Giữ file/API response gốc bất biến; ETL tạo dữ liệu chuẩn hóa riêng.
3. Đếm đơn bằng `COUNT(DISTINCT order_id)`, vì một đơn có thể có nhiều SKU.
4. Tách trạng thái đơn hàng, thanh toán, giao nhận, hoàn trả và trạng thái quyết toán hoa hồng.
5. Không có đối chiếu sao kê ngân hàng trong phạm vi hiện tại.
6. Demo dùng dữ liệu giả lập; không đưa file dữ liệu thực của doanh nghiệp vào GitHub hoặc demo.

## Tech stack gợi ý

- Frontend: React + TypeScript + Vite
- Backend: Python + FastAPI
- Database: PostgreSQL
- ORM/migration: SQLAlchemy 2 + Alembic
- Excel parsing: openpyxl hoặc thư viện tương đương ở phía backend
- Background sync: APScheduler cho demo; có thể nâng cấp worker/queue khi cần
- Local runtime: Docker Compose

## Cấu trúc code đích gợi ý

```text
app/
  frontend/
  backend/
    app/
      api/
      core/
      integrations/enterprise/
      ingestion/
      normalization/
      orders/
      commissions/
      reconciliation/
      reports/
      auth/
      models/
      schemas/
      repositories/
      services/
    tests/
  database/
    migrations/
    schema.sql
    seed_mock.sql
  storage/
    raw/                 # volume riêng, không commit file thật
  docs/
  docker-compose.yml
  .env.example
```

