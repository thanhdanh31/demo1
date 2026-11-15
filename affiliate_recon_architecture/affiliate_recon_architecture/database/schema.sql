-- PostgreSQL schema starter for TikTok Affiliate Reconciliation MIS
-- Do not add bank-statement or bank-reconciliation tables to this scope.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE app_users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    full_name VARCHAR(150) NOT NULL,
    password_hash TEXT NOT NULL,
    role VARCHAR(30) NOT NULL CHECK (role IN ('ADMIN','OWNER','OPS','HOST','EDITOR','VIEWER')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE api_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_code VARCHAR(80) NOT NULL,
    display_name VARCHAR(150) NOT NULL,
    environment VARCHAR(20) NOT NULL DEFAULT 'SANDBOX' CHECK (environment IN ('SANDBOX','UAT','PRODUCTION')),
    base_url TEXT,
    auth_type VARCHAR(40),
    granted_scopes TEXT[],
    credential_secret_ref TEXT, -- reference to secret manager / encrypted secret store; never store plain token here
    connection_status VARCHAR(30) NOT NULL DEFAULT 'NOT_CONFIGURED',
    last_tested_at TIMESTAMPTZ,
    last_successful_sync_at TIMESTAMPTZ,
    created_by BIGINT REFERENCES app_users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE sync_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    connection_id UUID REFERENCES api_connections(id),
    job_type VARCHAR(30) NOT NULL DEFAULT 'AFFILIATE_ORDERS',
    trigger_type VARCHAR(20) NOT NULL DEFAULT 'MANUAL' CHECK (trigger_type IN ('MANUAL','SCHEDULED','RETRY')),
    requested_from TIMESTAMPTZ,
    requested_to TIMESTAMPTZ,
    request_cursor TEXT,
    response_cursor TEXT,
    status VARCHAR(25) NOT NULL DEFAULT 'QUEUED',
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    pages_received INTEGER NOT NULL DEFAULT 0,
    rows_received INTEGER NOT NULL DEFAULT 0,
    rows_inserted INTEGER NOT NULL DEFAULT 0,
    rows_updated INTEGER NOT NULL DEFAULT 0,
    rows_unchanged INTEGER NOT NULL DEFAULT 0,
    rows_rejected INTEGER NOT NULL DEFAULT 0,
    error_code VARCHAR(100),
    error_message TEXT,
    triggered_by BIGINT REFERENCES app_users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_sync_jobs_created_at ON sync_jobs(created_at DESC);
CREATE INDEX idx_sync_jobs_status ON sync_jobs(status);

CREATE TABLE import_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sync_job_id UUID REFERENCES sync_jobs(id),
    source_format VARCHAR(20) NOT NULL CHECK (source_format IN ('JSON','XLSX','CSV','MANUAL_FIXTURE')),
    source_filename TEXT,
    source_content_type VARCHAR(120),
    checksum_sha256 CHAR(64),
    raw_storage_path TEXT NOT NULL,
    schema_version VARCHAR(80),
    row_count INTEGER NOT NULL DEFAULT 0,
    accepted_count INTEGER NOT NULL DEFAULT 0,
    rejected_count INTEGER NOT NULL DEFAULT 0,
    duplicate_count INTEGER NOT NULL DEFAULT 0,
    parse_status VARCHAR(25) NOT NULL DEFAULT 'PENDING',
    imported_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    imported_by BIGINT REFERENCES app_users(id),
    notes TEXT
);
CREATE INDEX idx_import_batches_imported_at ON import_batches(imported_at DESC);
CREATE INDEX idx_import_batches_checksum ON import_batches(checksum_sha256);

CREATE TABLE raw_records (
    id BIGSERIAL PRIMARY KEY,
    import_batch_id UUID NOT NULL REFERENCES import_batches(id) ON DELETE CASCADE,
    source_sheet VARCHAR(120),
    source_row_number INTEGER,
    source_record_key VARCHAR(255),
    raw_payload JSONB NOT NULL,
    raw_record_hash CHAR(64),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(import_batch_id, source_sheet, source_row_number)
);
CREATE INDEX idx_raw_records_payload_gin ON raw_records USING GIN(raw_payload);

CREATE TABLE contents (
    id BIGSERIAL PRIMARY KEY,
    connection_id UUID REFERENCES api_connections(id),
    external_content_id VARCHAR(80) NOT NULL,
    content_type VARCHAR(20) NOT NULL CHECK (content_type IN ('VIDEO','LIVE','SHOWCASE','OTHER')),
    title TEXT,
    owner_user_id BIGINT REFERENCES app_users(id),
    published_or_started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    source_payload JSONB,
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(connection_id, external_content_id, content_type)
);
CREATE INDEX idx_contents_type ON contents(content_type);

CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,
    connection_id UUID REFERENCES api_connections(id),
    external_order_id VARCHAR(80) NOT NULL,
    external_shop_id VARCHAR(80),
    shop_name TEXT,
    affiliate_partner_name TEXT,
    agency_name TEXT,
    currency CHAR(3) NOT NULL DEFAULT 'VND',
    source_order_type TEXT,
    indirect_attribution_raw TEXT,
    order_created_at TIMESTAMPTZ,
    source_created_at TIMESTAMPTZ,
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_import_batch_id UUID REFERENCES import_batches(id),
    source_payload JSONB,
    UNIQUE(connection_id, external_order_id)
);
CREATE INDEX idx_orders_created_at ON orders(order_created_at);
CREATE INDEX idx_orders_external_id ON orders(external_order_id);
CREATE INDEX idx_orders_shop ON orders(external_shop_id);

CREATE TABLE order_items (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    source_line_key VARCHAR(255) NOT NULL,
    external_order_item_id VARCHAR(80),
    external_sku_id VARCHAR(80),
    external_product_id VARCHAR(80),
    product_name TEXT,
    source_price NUMERIC(20,2),
    quantity_sold INTEGER NOT NULL DEFAULT 0 CHECK (quantity_sold >= 0),
    quantity_refunded INTEGER NOT NULL DEFAULT 0 CHECK (quantity_refunded >= 0),
    currency CHAR(3) NOT NULL DEFAULT 'VND',
    gmv_amount NUMERIC(20,2),
    source_content_type_raw TEXT,
    content_type VARCHAR(20) CHECK (content_type IN ('VIDEO','LIVE','SHOWCASE','OTHER')),
    external_content_id VARCHAR(80),
    content_id BIGINT REFERENCES contents(id),
    commission_type TEXT,
    standard_rate_percent NUMERIC(9,4),
    shop_ads_rate_or_amount_source TEXT,
    rotating_post_raw TEXT,
    last_import_batch_id UUID REFERENCES import_batches(id),
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    source_payload JSONB,
    UNIQUE(order_id, source_line_key)
);
CREATE INDEX idx_order_items_sku ON order_items(external_sku_id);
CREATE INDEX idx_order_items_content ON order_items(content_type, external_content_id);

-- Snapshot stores latest/source-observed lifecycle facts. Never infer missing dimensions.
CREATE TABLE order_status_snapshots (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    import_batch_id UUID NOT NULL REFERENCES import_batches(id),
    source_order_status_raw TEXT,
    normalized_order_status VARCHAR(30),
    source_payment_status_raw TEXT,
    payment_status VARCHAR(30),
    source_fulfillment_status_raw TEXT,
    fulfillment_status VARCHAR(30),
    source_refund_status_raw TEXT,
    refund_status VARCHAR(30),
    refunded_amount NUMERIC(20,2),
    source_updated_at TIMESTAMPTZ,
    observed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    source_payload JSONB,
    UNIQUE(order_id, import_batch_id)
);
CREATE INDEX idx_order_status_order_observed ON order_status_snapshots(order_id, observed_at DESC);
CREATE INDEX idx_order_status_payment ON order_status_snapshots(payment_status);
CREATE INDEX idx_order_status_fulfillment ON order_status_snapshots(fulfillment_status);
CREATE INDEX idx_order_status_refund ON order_status_snapshots(refund_status);

CREATE TABLE commission_snapshots (
    id BIGSERIAL PRIMARY KEY,
    order_item_id BIGINT NOT NULL REFERENCES order_items(id) ON DELETE CASCADE,
    import_batch_id UUID NOT NULL REFERENCES import_batches(id),
    commission_status_raw TEXT,
    commission_status VARCHAR(30) NOT NULL DEFAULT 'UNKNOWN',
    estimated_commission_base NUMERIC(20,2),
    estimated_standard_commission NUMERIC(20,2),
    estimated_shop_ads_commission NUMERIC(20,2),
    estimated_bonus NUMERIC(20,2),
    estimated_partner_bonus NUMERIC(20,2),
    estimated_iva_tax NUMERIC(20,2),
    estimated_isr_tax NUMERIC(20,2),
    estimated_cedular_tax NUMERIC(20,2),
    estimated_pit_tax NUMERIC(20,2),
    estimated_revenue_share NUMERIC(20,2),
    actual_commission_base NUMERIC(20,2),
    actual_standard_commission NUMERIC(20,2),
    actual_shop_ads_commission NUMERIC(20,2),
    actual_bonus NUMERIC(20,2),
    actual_partner_bonus NUMERIC(20,2),
    actual_isr_tax NUMERIC(20,2),
    actual_iva_tax NUMERIC(20,2),
    actual_cedular_tax NUMERIC(20,2),
    actual_pit_tax NUMERIC(20,2),
    shared_with_partner_amount NUMERIC(20,2),
    final_commission_amount_source NUMERIC(20,2),
    commission_settled_at TIMESTAMPTZ,
    source_updated_at TIMESTAMPTZ,
    observed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    source_payload JSONB,
    UNIQUE(order_item_id, import_batch_id)
);
CREATE INDEX idx_commission_status ON commission_snapshots(commission_status);
CREATE INDEX idx_commission_settled_at ON commission_snapshots(commission_settled_at);

CREATE TABLE reconciliation_runs (
    id BIGSERIAL PRIMARY KEY,
    run_code VARCHAR(50) NOT NULL UNIQUE,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    date_basis VARCHAR(30) NOT NULL DEFAULT 'ORDER_CREATED_AT' CHECK (date_basis IN ('ORDER_CREATED_AT','COMMISSION_SETTLED_AT')),
    as_of_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    status VARCHAR(25) NOT NULL DEFAULT 'DRAFT',
    total_orders INTEGER NOT NULL DEFAULT 0,
    total_order_items INTEGER NOT NULL DEFAULT 0,
    settled_orders INTEGER NOT NULL DEFAULT 0,
    pending_orders INTEGER NOT NULL DEFAULT 0,
    ineligible_orders INTEGER NOT NULL DEFAULT 0,
    unexplained_items INTEGER NOT NULL DEFAULT 0,
    summary JSONB,
    created_by BIGINT REFERENCES app_users(id),
    reviewed_by BIGINT REFERENCES app_users(id),
    reviewed_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (period_end >= period_start)
);

CREATE TABLE reconciliation_items (
    id BIGSERIAL PRIMARY KEY,
    reconciliation_run_id BIGINT NOT NULL REFERENCES reconciliation_runs(id) ON DELETE CASCADE,
    order_item_id BIGINT NOT NULL REFERENCES order_items(id),
    commission_snapshot_id BIGINT REFERENCES commission_snapshots(id),
    estimated_gross_commission NUMERIC(20,2),
    actual_gross_commission NUMERIC(20,2),
    final_commission_amount_source NUMERIC(20,2),
    comparable_difference NUMERIC(20,2),
    result_code VARCHAR(40) NOT NULL,
    reason_code VARCHAR(50),
    review_status VARCHAR(25) NOT NULL DEFAULT 'OPEN',
    reviewer_note TEXT,
    reviewed_by BIGINT REFERENCES app_users(id),
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(reconciliation_run_id, order_item_id)
);
CREATE INDEX idx_recon_items_result ON reconciliation_items(result_code, review_status);

CREATE TABLE data_quality_issues (
    id BIGSERIAL PRIMARY KEY,
    import_batch_id UUID NOT NULL REFERENCES import_batches(id) ON DELETE CASCADE,
    raw_record_id BIGINT REFERENCES raw_records(id),
    entity_type VARCHAR(40),
    source_row_number INTEGER,
    field_name VARCHAR(150),
    issue_code VARCHAR(50) NOT NULL,
    severity VARCHAR(15) NOT NULL DEFAULT 'WARNING' CHECK (severity IN ('INFO','WARNING','ERROR','CRITICAL')),
    raw_value TEXT,
    message TEXT NOT NULL,
    resolution_status VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    assigned_to BIGINT REFERENCES app_users(id),
    resolved_by BIGINT REFERENCES app_users(id),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_quality_issues_status ON data_quality_issues(resolution_status, severity);

CREATE TABLE status_mappings (
    id BIGSERIAL PRIMARY KEY,
    status_domain VARCHAR(30) NOT NULL CHECK (status_domain IN ('ORDER','PAYMENT','FULFILLMENT','REFUND','COMMISSION')),
    source_status_raw TEXT NOT NULL,
    normalized_status VARCHAR(40) NOT NULL,
    is_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    confirmed_by BIGINT REFERENCES app_users(id),
    confirmed_at TIMESTAMPTZ,
    notes TEXT,
    UNIQUE(status_domain, source_status_raw)
);

CREATE TABLE audit_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES app_users(id),
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(80),
    entity_id VARCHAR(100),
    before_data JSONB,
    after_data JSONB,
    reason TEXT,
    ip_address INET,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id, created_at DESC);

-- Suggested initial status mappings. Verify AwaitingPayment semantics with the source owner.
INSERT INTO status_mappings(status_domain, source_status_raw, normalized_status, is_confirmed, notes) VALUES
('COMMISSION','Đã quyết toán','SETTLED',TRUE,'Nguồn commission settlement status'),
('COMMISSION','Chờ xử lý','PENDING',TRUE,'Nguồn commission settlement status'),
('COMMISSION','Không đủ điều kiện','INELIGIBLE',TRUE,'Không tự suy ra order cancelled'),
('COMMISSION','AwaitingPayment','AWAITING_PAYMENT',FALSE,'Giữ nguyên; cần xác minh định nghĩa với API owner');

-- Note: no bank transaction table by design.
