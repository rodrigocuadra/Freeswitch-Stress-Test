-- ============================================================================================================
-- 📦 Database: freeswitch_cdr
-- 📘 Description: Dedicated CDR database schema for FreeSWITCH in Ring2All PBX Platform.
-- 🎯 Purpose: Tracks Call Detail Records (CDR) with multi-tenant support for analytics, billing, and auditing.
-- ⚠️ Notes:
--   - Replace placeholders like $r2a_cdr_database, $r2a_cdr_user, $r2a_cdr_password before executing.
--   - This file assumes core.tenants exists in the primary application database for tenant_id reference.
-- ============================================================================================================

-- 🎲 Create the database
CREATE DATABASE $fs_cdr_database;

-- 🔁 Connect to the new database
\connect $fs_cdr_database

-- 🔧 Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;  -- For uuid_generate_v4()
CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA public;    -- For trigram indexing
    
-- ============================================================================================================
-- 📂 Table: cdr
-- 📘 Description: Logs detailed call records for FreeSWITCH.
-- 🎯 Purpose: Enables call tracking and analysis per tenant.
-- 🔗 Relationships:
--   - tenant_id → core.tenants(id)
-- ⚙️ Optimizations:
--   - Indexed by tenant_id, timestamps, caller/destination numbers.
--   - Supports IPv4 validation and duration checks.
-- ============================================================================================================
CREATE TABLE cdr (
    id BIGSERIAL PRIMARY KEY,                                                       -- 🆔 Unique event ID
    uuid UUID NOT NULL DEFAULT uuid_generate_v4(),                                  -- 🆔 Public UUID for external reference
    local_ip_v4 INET,                                                               -- 🌐 Local IP address
    domain_name VARCHAR(255),                                                       -- 🏠 Domain name
    caller_id_name VARCHAR(255),                                                    -- 📞 Caller Name
    caller_id_number VARCHAR(50),                                                   -- 📱 Caller Number
    destination_number VARCHAR(50),                                                 -- 🎯 Destination Number
    direction VARCHAR(20),                                                          -- 🧭 Call direction (inbound, outbound, local)
    context VARCHAR(50),                                                            -- 🧭 Dialplan context
    start_stamp TIMESTAMPTZ,                                                        -- 🕒 Call Start
    answer_stamp TIMESTAMPTZ,                                                       -- 📞 Answered
    end_stamp TIMESTAMPTZ,                                                          -- 🛑 Call End
    duration INTEGER CHECK (duration >= 0),                                         -- ⏱️ Total Duration
    billsec INTEGER CHECK (billsec >= 0),                                           -- 💰 Billable Seconds
    pdd_ms INTEGER CHECK (pdd_ms >= 0),                                             -- ⏳ Post-Dial Delay (ms)
    hangup_cause VARCHAR(50),                                                       -- ❌ Hangup Reason
    bridge_uuid UUID,                                                               -- 🔗 Bridge UUID (optional)
    accountcode VARCHAR(50),                                                        -- 🧾 Billing Code
    read_codec VARCHAR(50),                                                         -- 🔊 Codec IN
    write_codec VARCHAR(50),                                                        -- 🔊 Codec OUT
    remote_media_ip INET,                                                           -- 🌐 Remote media IP (RTP)
    network_addr INET,                                                              -- 🌐 Network signaling IP
    recording_file TEXT,                                                            -- 🎙️ Recording file path
    last_app VARCHAR(50),                                                           -- 🛠️ Last application executed
    last_arg TEXT,                                                                  -- 📋 Last application arguments
    sip_hangup_disposition VARCHAR(50),                                             -- 📡 SIP hangup disposition
    insert_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),                                 -- 🕓 Created timestamp
    CONSTRAINT valid_ip_local CHECK (local_ip_v4 IS NULL OR family(local_ip_v4) = 4),                -- 🛡️ Valid IPv4 only for local_ip_v4
    CONSTRAINT valid_ip_remote CHECK (remote_media_ip IS NULL OR family(remote_media_ip) IN (4, 6)), -- 🛡️ Valid IPv4/IPv6 for remote_media_ip
    CONSTRAINT valid_ip_network CHECK (network_addr IS NULL OR family(network_addr) IN (4, 6))       -- 🛡️ Valid IPv4/IPv6 for network_addr
);

-- 📈 Indexes for performance
CREATE INDEX idx_cdr_uuid ON cdr (uuid);
CREATE INDEX idx_cdr_local_ip_v4 ON cdr (local_ip_v4);
CREATE INDEX idx_cdr_domain_name ON cdr (domain_name) WHERE domain_name IS NOT NULL;
CREATE INDEX idx_cdr_start_stamp ON cdr (start_stamp) WHERE start_stamp IS NOT NULL;
CREATE INDEX idx_cdr_end_stamp ON cdr (end_stamp) WHERE end_stamp IS NOT NULL;
CREATE INDEX idx_cdr_caller_id_number ON cdr (caller_id_number) WHERE caller_id_number IS NOT NULL;
CREATE INDEX idx_cdr_destination_number ON cdr (destination_number) WHERE destination_number IS NOT NULL;
CREATE INDEX idx_cdr_direction ON cdr (direction) WHERE direction IS NOT NULL;
CREATE INDEX idx_cdr_hangup_cause ON cdr (hangup_cause) WHERE hangup_cause IS NOT NULL;
CREATE INDEX idx_cdr_accountcode ON cdr (accountcode) WHERE accountcode IS NOT NULL;
CREATE INDEX idx_cdr_bridge_uuid ON cdr (bridge_uuid) WHERE bridge_uuid IS NOT NULL;
CREATE INDEX idx_cdr_caller_destination ON cdr (caller_id_number, destination_number);
CREATE INDEX idx_cdr_remote_media_ip ON cdr (remote_media_ip) WHERE remote_media_ip IS NOT NULL;
CREATE INDEX idx_cdr_network_addr ON cdr (network_addr) WHERE network_addr IS NOT NULL;
CREATE INDEX idx_cdr_insert_date ON cdr (insert_date);

-- ============================================================================================================
-- 👤 Role Creation: $r2a_cdr_user
-- 📘 Description: Grants access to CDR system user.
-- 🔐 Suggestion: Use limited permissions (INSERT, SELECT, UPDATE) in production.
-- ============================================================================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$fs_cdr_user') THEN
        EXECUTE 'CREATE ROLE ' || quote_ident('$fs_cdr_user') || ' WITH LOGIN PASSWORD ' || quote_literal('$fs_cdr_password');
    END IF;
END $$;

-- ============================================================================================================
-- 🛡️ Privileges
-- ============================================================================================================
GRANT ALL PRIVILEGES ON DATABASE $fs_cdr_database TO $fs_cdr_user;
GRANT ALL PRIVILEGES ON SCHEMA public TO $fs_cdr_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $fs_cdr_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $fs_cdr_user;
GRANT ALL PRIVILEGES ON cdr TO $fs_cdr_user;
GRANT ALL PRIVILEGES ON SEQUENCE cdr_id_seq TO $fs_cdr_user;
ALTER TABLE cdr OWNER TO $fs_cdr_user;
