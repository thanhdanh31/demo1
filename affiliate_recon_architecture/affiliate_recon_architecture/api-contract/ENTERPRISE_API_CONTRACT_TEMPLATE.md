# Enterprise API Contract – Template cần doanh nghiệp điền/xác nhận

> Không tự điền endpoint, header, token flow hoặc response fields khi chưa có tài liệu của doanh nghiệp.

## 1. Thông tin kết nối

- Tên hệ thống doanh nghiệp:
- Môi trường: Sandbox / UAT / Production
- Base URL:
- Người phụ trách kỹ thuật:
- Cơ chế xác thực: API Key / OAuth2 / HMAC / khác
- Cách refresh/revoke credential:
- IP allowlist/VPN/mTLS nếu có:
- Quyền truy cập/scopes:

## 2. Endpoint lấy Affiliate export

- HTTP method:
- Path:
- Query parameters:
- Headers:
- Request body:
- Response Content-Type: JSON / XLSX / CSV / file URL
- Pagination: page/page_size/cursor/next_token
- Rate limit:
- Timeout:
- Error codes:
- Sample response/file đã che dữ liệu nhạy cảm:

## 3. Endpoint lấy order lifecycle

- Có endpoint payment status không? Path:
- Có endpoint fulfillment/delivery status không? Path:
- Có endpoint cancellation không? Path:
- Có endpoint refund/return details không? Path:
- Trường ID dùng để ghép với Affiliate export:
- Thời gian cập nhật trạng thái:
- Có lịch sử trạng thái hay chỉ trạng thái hiện tại?

## 4. Endpoint hoa hồng

- Estimated commission fields:
- Actual commission components:
- Final commission amount:
- Commission settlement status:
- Settlement timestamp:
- Refund/cancel adjustment fields:
- Tax/partner share/bonus components:
- Định nghĩa chính thức của `AwaitingPayment`:
- Định nghĩa `Không đủ điều kiện`:

## 5. Incremental sync

- Có `updated_at` không?
- Có truy vấn theo `created_at` hoặc `updated_at` không?
- Có cursor/checkpoint không?
- Độ trễ dữ liệu thông thường:
- Dữ liệu có thể bị thay đổi sau nhiều ngày không?
- Số ngày cần backfill:

## 6. Bảo mật và lưu trữ

- Dữ liệu nào được phép lưu?
- Có được giữ raw export không? Bao lâu?
- Có được lưu ID đơn/SKU/content không?
- Có trường dữ liệu cá nhân cần loại bỏ không?
- Ai được cấp quyền tải file thô?
- Quy trình thu hồi quyền truy cập:
