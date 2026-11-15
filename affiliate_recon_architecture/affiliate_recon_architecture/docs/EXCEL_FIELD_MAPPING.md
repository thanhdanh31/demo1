# Mapping 48 cột workbook Affiliate Orders

Nguồn: workbook `affiliate_orders_7701771192566925077.xlsx` do người dùng cung cấp. Tài liệu này chỉ ghi tên cột và đích dữ liệu, không sao chép dòng dữ liệu thực.

| # | Tên cột nguồn | Trường chuẩn hóa gợi ý | Quy tắc |
|---:|---|---|---|
| 1 | ID đơn hàng | `external_order_id` | String; khóa đơn |
| 2 | ID SKU | `external_sku_id` | String; mã SKU |
| 3 | Tên sản phẩm | `product_name` | Text |
| 4 | ID sản phẩm | `external_product_id` | String |
| 5 | Giá | `unit_or_line_price_source` | Numeric; cần xác nhận định nghĩa giá với API |
| 6 | Số món bán ra | `quantity_sold` | Integer >= 0 |
| 7 | Số món đã hoàn tiền | `quantity_refunded` | Integer >= 0 |
| 8 | Tên cửa hàng | `shop_name` | Text |
| 9 | Mã cửa hàng | `external_shop_id` | String |
| 10 | Đối tác liên kết | `affiliate_partner_name` | Text/nullable |
| 11 | Agency | `agency_name` | Text/nullable |
| 12 | Đơn vị tiền tệ | `currency` | ISO-like code, ví dụ VND |
| 13 | Loại đơn hàng | `source_order_type` | Giữ raw; không đồng nhất content type |
| 14 | Trạng thái quyết toán đơn hàng | `commission_status_raw` | Giữ raw + mapping có kiểm duyệt |
| 15 | Gián tiếp | `is_indirect_attribution_raw` | Giữ raw, xác nhận kiểu dữ liệu |
| 16 | Loại hoa hồng | `commission_type` | Text/enum raw |
| 17 | Loại nội dung | `content_type_raw` | Map Video/LIVE/Showcase |
| 18 | Bài xoay vòng | `rotating_post_raw` | Giữ raw; xác minh nghĩa |
| 19 | Id nội dung | `external_content_id` | String; không cast số |
| 20 | Tiêu chuẩn | `standard_rate_percent` | Parse `5%` thành 5.0 |
| 21 | Quảng cáo cửa hàng | `shop_ads_rate_or_amount_source` | Xác minh đơn vị theo API |
| 22 | TikTok thưởng | `tiktok_reward_source` | Giữ raw; xác minh semantics |
| 23 | Đối tác thưởng | `partner_reward_source` | Giữ raw; xác minh semantics |
| 24 | Phần chia doanh thu | `revenue_share_source` | Numeric/raw; xác minh đơn vị |
| 25 | GMV | `gmv_amount` | Decimal; VND locale |
| 26 | Cơ sở hoa hồng ước tính | `estimated_commission_base` | Decimal |
| 27 | Hoa hồng tiêu chuẩn ước tính | `estimated_standard_commission` | Decimal |
| 28 | Hoa hồng Quảng cáo cửa hàng ước tính | `estimated_shop_ads_commission` | Decimal |
| 29 | Thưởng ước tính | `estimated_bonus` | Decimal |
| 30 | Thưởng ước tính của đối tác liên kết | `estimated_partner_bonus` | Decimal |
| 31 | IVA ước tính | `estimated_iva_tax` | Decimal |
| 32 | ISR ước tính | `estimated_isr_tax` | Decimal |
| 33 | Est. CedularTax | `estimated_cedular_tax` | Decimal |
| 34 | PIT ước tính | `estimated_pit_tax` | Decimal |
| 35 | Ước tính phần chia doanh thu | `estimated_revenue_share` | Decimal |
| 36 | Cơ sở hoa hồng thực tế | `actual_commission_base` | Decimal |
| 37 | Hoa hồng tiêu chuẩn | `actual_standard_commission` | Decimal |
| 38 | Hoa hồng Quảng cáo cửa hàng | `actual_shop_ads_commission` | Decimal |
| 39 | Thưởng | `actual_bonus` | Decimal |
| 40 | Thưởng của đối tác liên kết | `actual_partner_bonus` | Decimal |
| 41 | Thuế - ISR | `actual_isr_tax` | Decimal; giữ dấu âm/dương theo nguồn |
| 42 | Thuế - IVA | `actual_iva_tax` | Decimal |
| 43 | cedular_tax | `actual_cedular_tax` | Decimal |
| 44 | Thuế - PIT | `actual_pit_tax` | Decimal |
| 45 | Đã chia sẻ với đối tác | `shared_with_partner_amount` | Decimal |
| 46 | Tổng số tiền nhận được cuối cùng | `final_commission_amount_source` | Giá trị cuối theo báo cáo TikTok/doanh nghiệp; KHÔNG phải bank receipt |
| 47 | Ngày đặt hàng | `order_created_at` | Parse dd/MM/yyyy HH:mm:ss; timezone do API xác nhận |
| 48 | Ngày quyết toán hoa hồng | `commission_settled_at` | Nullable nếu chưa settled |

## Những quy tắc bắt buộc

- ID 18-19 chữ số phải là string; JavaScript Number có thể làm mất độ chính xác.
- Một dòng nguồn là dòng chi tiết order/SKU, không mặc định là một đơn hàng.
- Tên tiền `248.399` trong file mẫu sử dụng dấu chấm làm phân cách hàng nghìn: parse theo locale VND thành `248399`. Phải có test parser cho trường hợp này.
- `/` hoặc ô trống không tự động chuyển thành 0; dùng NULL nếu chưa có giá trị.
- Trạng thái nguồn phải luôn được giữ nguyên để truy vết.
- `Loại nội dung` khác `Loại đơn hàng`.
- `commission_status_raw` không thay thế `payment_status` hoặc `fulfillment_status`.
- Trường `final_commission_amount_source` không được đổi tên thành `bank_received_amount` hoặc `cash_received`.
