-- ═══════════════════════════════════════════════════════════════════════════════
-- Bearthen — Local SQLite Schema  (qml/js/Library.js canonical reference)
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Engine : Qt WebSQL / SQLite (openDatabaseSync)
-- Location on device:
--   /home/phablet/.local/share/bearthen.russs95/Databases/<hash>.sqlite
-- Inspect from ADB shell:
--   sqlite3 /home/phablet/.local/share/bearthen.russs95/Databases/*.sqlite
--
-- All timestamps are Unix epoch seconds (INTEGER).
-- Percentages are REAL (0–100), stored as INTEGER column but SQLite is
-- transparent — fractional values (e.g. 42.87) round-trip without truncation.
--
-- This file documents the schema as deployed; authoritative source is Library.js.
-- ═══════════════════════════════════════════════════════════════════════════════

-- ── books_tb ──────────────────────────────────────────────────────────────────
-- One row per book in the user's local library.
-- Covers both public-domain catalog books (source = "gutenberg") and
-- user-imported EPUB files (source = "local").
--
CREATE TABLE IF NOT EXISTS books_tb (
    id                TEXT    PRIMARY KEY,          -- "local_<hash>" | gutenberg numeric string
    title             TEXT    NOT NULL,
    author_id         TEXT,                         -- FK → authors_tb.id (if known)
    author_display    TEXT,
    cover_url         TEXT    DEFAULT "",           -- data:image/jpeg;base64,… thumbnail OR remote URL
    cover_local       TEXT    DEFAULT "",           -- bare file path (no file://) to local image
    epub_url          TEXT    DEFAULT "",           -- remote HTTPS URL (Gutenberg books)
    file_path         TEXT    DEFAULT "",           -- file:// URL to local EPUB on device
    source            TEXT    DEFAULT "gutenberg",  -- "gutenberg" | "local"
    source_id         TEXT    DEFAULT "",           -- bare path for local; Gutenberg ID for remote
    category          TEXT    DEFAULT "other",
    subjects          TEXT    DEFAULT "[]",         -- JSON array of subject strings
    language          TEXT    DEFAULT "en",
    date_added        INTEGER DEFAULT 0,            -- Unix epoch seconds
    last_read         INTEGER DEFAULT 0,            -- Unix epoch seconds
    read_percent      INTEGER DEFAULT 0,            -- 0–100 (stored REAL-compatible)
    read_position     TEXT    DEFAULT "",           -- epub.js CFI string for exact page restore
    is_finished       INTEGER DEFAULT 0,            -- 0 | 1
    tags              TEXT    DEFAULT "[]",         -- JSON array of user tag strings
    notes             TEXT    DEFAULT "",
    eco_score         REAL,
    downloads         INTEGER DEFAULT 0,
    copyright         INTEGER,                      -- NULL=unknown, 0=public domain, 1=copyrighted
    birth_year        INTEGER,
    death_year        INTEGER,
    description       TEXT    DEFAULT "",
    publisher         TEXT    DEFAULT "",
    file_size_kb      INTEGER DEFAULT 0,
    published_date    TEXT    DEFAULT "",
    -- Reader preference columns (added via ALTER TABLE migration):
    reader_fontsize   INTEGER DEFAULT 385,          -- CSS internal unit; 385 ≈ 100% display size
    reader_fontfamily TEXT    DEFAULT "georgia",
    reader_theme      TEXT    DEFAULT "dark",       -- "dark" | "light" | "sepia"
    reader_spacing    TEXT    DEFAULT "normal",     -- "tight" | "normal" | "loose"
    reader_margins    TEXT    DEFAULT "normal"      -- "narrow" | "normal" | "wide"
);

-- ── authors_tb ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS authors_tb (
    id           TEXT PRIMARY KEY,
    name_display TEXT NOT NULL,
    name_sort    TEXT NOT NULL,                     -- "Last, First" format
    birth_year   INTEGER,
    death_year   INTEGER,
    nationality  TEXT
);

-- ── reading_lists_tb ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reading_lists_tb (
    id          TEXT PRIMARY KEY,                   -- "list-starred" | "list-<random9>"
    name        TEXT NOT NULL,
    description TEXT DEFAULT "",
    created_at  INTEGER DEFAULT 0,
    updated_at  INTEGER DEFAULT 0
);

-- ── reading_list_entries_tb ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reading_list_entries_tb (
    list_id  TEXT    NOT NULL,
    book_id  TEXT    NOT NULL,
    position INTEGER DEFAULT 0,
    PRIMARY KEY (list_id, book_id)
);

-- ── bookmarks_tb ──────────────────────────────────────────────────────────────
-- Multiple saved positions per book (distinct from the single read_position
-- auto-save in books_tb). Each bookmark has a user-assigned label and colour.
--
CREATE TABLE IF NOT EXISTS bookmarks_tb (
    id         TEXT    PRIMARY KEY,                 -- "bm_<epoch>_<rand4>"
    book_id    TEXT    NOT NULL,
    cfi        TEXT    NOT NULL,                    -- epub.js CFI string
    pct        INTEGER DEFAULT 0,                   -- approximate % location
    label      TEXT    DEFAULT "",
    created_at INTEGER DEFAULT 0,
    color      TEXT    DEFAULT "#4CAF50"
);

-- ── highlights_tb ─────────────────────────────────────────────────────────────
-- Colour-coded text annotations per book.
--
CREATE TABLE IF NOT EXISTS highlights_tb (
    id         TEXT    PRIMARY KEY,
    book_id    TEXT    NOT NULL,
    cfi        TEXT    NOT NULL,                    -- epub.js range CFI
    pct        REAL    DEFAULT 0.0,
    text       TEXT    DEFAULT "",                  -- selected passage text
    color      TEXT    DEFAULT "#FFC107",
    created_at INTEGER DEFAULT 0
);

-- Seed "Starred" reading list (INSERT OR IGNORE — safe to run every boot):
-- INSERT OR IGNORE INTO reading_lists_tb
--     (id, name, description, created_at, updated_at)
--     VALUES ('list-starred', 'Starred', 'Your starred books', <now>, <now>);


-- ═══════════════════════════════════════════════════════════════════════════════
-- Bearthen Online — MySQL Schema  (companion to the local SQLite schema above)
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Purpose : cloud sync backend for multi-device Bearthen use.
--           A future bearthen.earthen.io web/API server (Node.js / Express,
--           mirroring the airbuddy-ONLINE architecture) would own this database.
--
-- Engine  : MySQL 8.0+ / MariaDB 10.5+
-- Charset : utf8mb4, Collation utf8mb4_unicode_ci  (emoji + CJK safe)
-- Times   : all DATETIME columns stored as UTC; convert to local in the app layer
-- Auth    : Buwana SSO — users identified by buwana_sub (stable across app reinstalls)
--
-- Design principles
-- ─────────────────
-- 1. Catalog data (title, author, cover, subjects) is shared across all users.
--    Per-user state (progress, position, prefs, tags, notes) lives separately.
-- 2. Every syncable table carries updated_at + deleted_at for delta sync.
--    Deleted rows are soft-deleted (deleted_at IS NOT NULL) so device clients
--    learn about removals on their next sync pull.
-- 3. Conflict resolution strategy:
--    • read_percent / read_position : furthest position wins
--      (highest read_percent; ties broken by updated_at)
--    • Reader prefs per book        : last-write-wins (latest updated_at)
--    • Bookmarks / highlights       : union merge; deleted_at handles removals
--    • Reading list membership      : union merge; deleted_at handles removals
-- 4. Local book IDs map directly:
--    • Gutenberg books   — numeric string ("84", "1342")
--    • User-uploaded     — "local_<hash>" (hash of original filename)
--    • Bearthen store    — "bearthen_<slug>" (e.g. "bearthen_tractatus")
--    The catalog_books_tb.id column uses the same scheme so no remapping is
--    needed on sync.
-- ═══════════════════════════════════════════════════════════════════════════════

SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- ── users_tb ──────────────────────────────────────────────────────────────────
-- One row per Buwana-authenticated user.
-- buwana_sub is the stable OIDC subject identifier ("sub" claim in the JWT).
-- Sync clients identify themselves as (user_id, device_id) pairs.
--
CREATE TABLE IF NOT EXISTS users_tb (
    id              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    buwana_sub      VARCHAR(128)    NOT NULL,           -- Buwana OIDC "sub" claim
    email           VARCHAR(255),
    display_name    VARCHAR(255),
    avatar_url      VARCHAR(1024),
    language        VARCHAR(8)      DEFAULT 'en',       -- UI language preference
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_buwana_sub (buwana_sub)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ── authors_tb ────────────────────────────────────────────────────────────────
-- Shared catalog of known authors. Populated from Gutenberg metadata and
-- user-import EPUB OPF data.
--
CREATE TABLE IF NOT EXISTS authors_tb (
    id              VARCHAR(128)    NOT NULL,            -- Gutenberg author slug or generated
    name_display    VARCHAR(512)    NOT NULL,
    name_sort       VARCHAR(512)    NOT NULL,            -- "Last, First" for sorting
    birth_year      SMALLINT        UNSIGNED,
    death_year      SMALLINT        UNSIGNED,
    nationality     VARCHAR(128),
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ── catalog_books_tb ──────────────────────────────────────────────────────────
-- Shared catalog of books whose metadata is public or curated by Bearthen.
-- This covers:
--   source = "gutenberg"  — Project Gutenberg public domain books
--   source = "bearthen"   — Books sold or distributed by the Bearthen store
--                           (e.g. Tractatus Ayyew: id = "bearthen_tractatus")
--
-- User-uploaded EPUBs (source = "local") do NOT have rows here; their
-- per-user metadata lives entirely in user_books_tb + user_uploads_tb.
--
-- The id column deliberately mirrors the local SQLite id values so that the
-- QML app can match records without a translation step.
--
CREATE TABLE IF NOT EXISTS catalog_books_tb (
    id              VARCHAR(128)    NOT NULL,            -- Gutenberg numeric or "bearthen_<slug>"
    title           VARCHAR(1024)   NOT NULL,
    author_id       VARCHAR(128),                        -- FK → authors_tb.id
    author_display  VARCHAR(512),
    language        VARCHAR(8)      DEFAULT 'en',
    category        VARCHAR(128)    DEFAULT 'other',
    subjects        JSON,                                -- ["Fiction", "Science Fiction", …]
    cover_url       VARCHAR(2048)   DEFAULT '',          -- remote HTTPS URL to cover image
    epub_url        VARCHAR(2048)   DEFAULT '',          -- remote HTTPS URL to EPUB file
    source          VARCHAR(32)     NOT NULL DEFAULT 'gutenberg',
    source_id       VARCHAR(256)    DEFAULT '',          -- Gutenberg numeric id or bearthen slug
    description     TEXT,
    publisher       VARCHAR(512),
    published_date  VARCHAR(32),
    birth_year      SMALLINT        UNSIGNED,
    death_year      SMALLINT        UNSIGNED,
    copyright       TINYINT(1),                          -- NULL=unknown, 0=PD, 1=copyrighted
    downloads       INT UNSIGNED    DEFAULT 0,
    file_size_kb    INT UNSIGNED    DEFAULT 0,
    -- Bearthen store fields (NULL for non-store books)
    store_price_cents   INT UNSIGNED,                   -- e.g. 1000 = $10.00 USD
    store_currency      VARCHAR(8),                      -- "USD", "EUR" etc.
    store_epub_key      VARCHAR(256),                    -- object-storage key for protected EPUB
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_source          (source),
    KEY idx_language        (language),
    KEY idx_author          (author_id),
    CONSTRAINT fk_catbook_author FOREIGN KEY (author_id)
        REFERENCES authors_tb (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ── user_books_tb ─────────────────────────────────────────────────────────────
-- Per-user library membership and reading state.
-- One row per (user, book) pair for every book in any user's library —
-- whether the book is in the shared catalog or a personal upload.
--
-- book_id matches catalog_books_tb.id for catalog books, or
-- "local_<hash>" for user-uploaded EPUBs (those also have a row in user_uploads_tb).
--
-- Sync notes
-- ──────────
-- • updated_at is bumped on any field change; the sync API returns rows
--   WHERE updated_at > :last_sync_at AND user_id = :user_id.
-- • deleted_at IS NOT NULL means the user removed this book from their library.
--   The row is kept so other devices learn about the removal.
-- • read_percent conflict: take MAX(read_percent); break ties by updated_at.
--
CREATE TABLE IF NOT EXISTS user_books_tb (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id         INT UNSIGNED    NOT NULL,
    book_id         VARCHAR(128)    NOT NULL,            -- catalog id or "local_<hash>"
    -- Metadata fields (only populated for local uploads; catalog books use catalog_books_tb)
    title           VARCHAR(1024),                       -- NULL = defer to catalog_books_tb
    author_display  VARCHAR(512),
    language        VARCHAR(8),
    description     TEXT,
    publisher       VARCHAR(512),
    published_date  VARCHAR(32),
    file_size_kb    INT UNSIGNED    DEFAULT 0,
    -- Library state
    source          VARCHAR(32)     NOT NULL DEFAULT 'gutenberg',   -- "gutenberg"|"bearthen"|"local"
    category        VARCHAR(128)    DEFAULT 'other',
    date_added      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_read       DATETIME,
    read_percent    DECIMAL(6,2)    DEFAULT 0.00,        -- 0.00–100.00
    read_position   TEXT,                                -- epub.js CFI string
    is_finished     TINYINT(1)      DEFAULT 0,
    tags            JSON,                                -- ["want-to-read", …]
    notes           TEXT,
    eco_score       DECIMAL(5,2),
    -- Per-book reader preferences (override the user-level defaults)
    reader_fontsize   SMALLINT UNSIGNED DEFAULT 385,     -- CSS internal unit
    reader_fontfamily VARCHAR(64)    DEFAULT 'georgia',
    reader_theme      VARCHAR(32)    DEFAULT 'dark',     -- "dark"|"light"|"sepia"
    reader_spacing    VARCHAR(32)    DEFAULT 'normal',   -- "tight"|"normal"|"loose"
    reader_margins    VARCHAR(32)    DEFAULT 'normal',   -- "narrow"|"normal"|"wide"
    -- Sync bookkeeping
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,
    deleted_at      DATETIME,                            -- soft delete for sync
    PRIMARY KEY (id),
    UNIQUE KEY uq_user_book     (user_id, book_id),
    KEY idx_user_updated        (user_id, updated_at),
    KEY idx_user_last_read      (user_id, last_read),
    KEY idx_book_id             (book_id),
    CONSTRAINT fk_userbook_user FOREIGN KEY (user_id)
        REFERENCES users_tb (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ── user_uploads_tb ───────────────────────────────────────────────────────────
-- Tracks EPUB files that users have uploaded from their device to cloud storage.
-- Enables the "back up my local books" and cross-device library features.
-- Actual bytes live in object storage (e.g. S3-compatible); this table holds
-- the metadata and storage reference.
--
-- storage_key is the object key in the bucket.
-- The presigned download URL is generated on demand by the API; never stored here.
--
CREATE TABLE IF NOT EXISTS user_uploads_tb (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id         INT UNSIGNED    NOT NULL,
    book_id         VARCHAR(128)    NOT NULL,            -- "local_<hash>" — matches user_books_tb
    original_filename   VARCHAR(512),
    storage_key     VARCHAR(1024),                       -- object storage key
    content_hash    VARCHAR(64),                         -- SHA-256 hex of the EPUB bytes
    file_size_bytes BIGINT UNSIGNED DEFAULT 0,
    upload_status   ENUM('pending','processing','ready','failed')
                                    DEFAULT 'pending',
    cover_url       VARCHAR(2048),                       -- extracted cover stored in object storage
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_user_book_upload  (user_id, book_id),
    KEY idx_user_uploads_user       (user_id),
    CONSTRAINT fk_upload_user FOREIGN KEY (user_id)
        REFERENCES users_tb (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ── bookmarks_tb ──────────────────────────────────────────────────────────────
-- Per-user, per-book named bookmarks (distinct from the auto-saved read_position).
-- The local ID scheme "bm_<epoch>_<rand4>" is preserved as-is; the combination
-- (user_id, local_id) is effectively unique across devices.
-- On sync conflict: union merge — both sides keep all bookmarks; deletions
-- propagate via deleted_at.
--
CREATE TABLE IF NOT EXISTS bookmarks_tb (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    local_id        VARCHAR(64)     NOT NULL,            -- "bm_<epoch>_<rand4>" from device
    user_id         INT UNSIGNED    NOT NULL,
    book_id         VARCHAR(128)    NOT NULL,
    cfi             TEXT            NOT NULL,            -- epub.js CFI string
    pct             DECIMAL(6,2)    DEFAULT 0.00,
    label           VARCHAR(512)    DEFAULT '',
    color           VARCHAR(16)     DEFAULT '#4CAF50',
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,
    deleted_at      DATETIME,                            -- soft delete for sync
    PRIMARY KEY (id),
    UNIQUE KEY uq_user_local_bm     (user_id, local_id),
    KEY idx_bm_user_book            (user_id, book_id),
    KEY idx_bm_updated              (user_id, updated_at),
    CONSTRAINT fk_bm_user FOREIGN KEY (user_id)
        REFERENCES users_tb (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ── highlights_tb ─────────────────────────────────────────────────────────────
-- Per-user, per-book colour-coded text highlights.
-- local_id is generated in reader.html at highlight creation time.
-- Merge strategy same as bookmarks: union with soft-delete propagation.
--
CREATE TABLE IF NOT EXISTS highlights_tb (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    local_id        VARCHAR(128)    NOT NULL,            -- generated by reader.html
    user_id         INT UNSIGNED    NOT NULL,
    book_id         VARCHAR(128)    NOT NULL,
    cfi             TEXT            NOT NULL,            -- epub.js range CFI
    pct             DECIMAL(6,2)    DEFAULT 0.00,
    text            TEXT,                                -- selected passage text
    color           VARCHAR(16)     DEFAULT '#FFC107',
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,
    deleted_at      DATETIME,
    PRIMARY KEY (id),
    UNIQUE KEY uq_user_local_hl     (user_id, local_id),
    KEY idx_hl_user_book            (user_id, book_id),
    KEY idx_hl_updated              (user_id, updated_at),
    CONSTRAINT fk_hl_user FOREIGN KEY (user_id)
        REFERENCES users_tb (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ── reading_lists_tb ──────────────────────────────────────────────────────────
-- Per-user named reading lists.
-- The "Starred" list is seeded on account creation (local_id = "list-starred").
-- Other lists use "list-<random9>" IDs from the device.
--
CREATE TABLE IF NOT EXISTS reading_lists_tb (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    local_id        VARCHAR(64)     NOT NULL,            -- "list-starred" | "list-<rand9>"
    user_id         INT UNSIGNED    NOT NULL,
    name            VARCHAR(512)    NOT NULL,
    description     TEXT,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,
    deleted_at      DATETIME,
    PRIMARY KEY (id),
    UNIQUE KEY uq_user_local_list   (user_id, local_id),
    KEY idx_list_user               (user_id),
    CONSTRAINT fk_list_user FOREIGN KEY (user_id)
        REFERENCES users_tb (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ── reading_list_entries_tb ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reading_list_entries_tb (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    list_id         BIGINT UNSIGNED NOT NULL,            -- FK → reading_lists_tb.id
    book_id         VARCHAR(128)    NOT NULL,
    position        SMALLINT        UNSIGNED DEFAULT 0,
    added_at        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,
    deleted_at      DATETIME,
    PRIMARY KEY (id),
    UNIQUE KEY uq_list_book         (list_id, book_id),
    KEY idx_rle_list                (list_id),
    KEY idx_rle_updated             (list_id, updated_at),
    CONSTRAINT fk_rle_list FOREIGN KEY (list_id)
        REFERENCES reading_lists_tb (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ── devices_tb ────────────────────────────────────────────────────────────────
-- Registered devices for each user.
-- Each device tracks its own last_sync_at so the sync API can return
-- only the delta (rows changed since that timestamp).
--
-- platform values: "ubuntu_touch" | "web" | "android" | "ios" | "desktop"
--
CREATE TABLE IF NOT EXISTS devices_tb (
    id              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    user_id         INT UNSIGNED    NOT NULL,
    device_name     VARCHAR(256),                        -- human-readable e.g. "Pinephone"
    platform        VARCHAR(32)     DEFAULT 'ubuntu_touch',
    device_token    VARCHAR(256),                        -- optional push-notification token
    last_sync_at    DATETIME,                            -- NULL = never synced
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_dev_user    (user_id),
    CONSTRAINT fk_dev_user FOREIGN KEY (user_id)
        REFERENCES users_tb (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ── purchases_tb ──────────────────────────────────────────────────────────────
-- Records paid book purchases for the Bearthen store.
-- Currently covers Tractatus Ayyew (book_id = "bearthen_tractatus") and any
-- future titles added to catalog_books_tb with a store_price_cents value.
--
-- The purchase record gates download of the protected EPUB: the API checks
-- purchases_tb before issuing a presigned object-storage URL.
--
-- payment_provider: "stripe" | "paypal" | "manual" | "promo"
-- status: "pending" → "completed" | "failed" | "refunded"
--
CREATE TABLE IF NOT EXISTS purchases_tb (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id             INT UNSIGNED    NOT NULL,
    book_id             VARCHAR(128)    NOT NULL,        -- FK → catalog_books_tb.id
    amount_cents        INT UNSIGNED    NOT NULL,        -- amount actually charged
    currency            VARCHAR(8)      NOT NULL DEFAULT 'USD',
    payment_provider    VARCHAR(32)     DEFAULT 'stripe',
    payment_ref         VARCHAR(512),                    -- Stripe charge id / PayPal tx id etc.
    status              ENUM('pending','completed','failed','refunded')
                                        DEFAULT 'pending',
    purchased_at        DATETIME,                        -- set when status → completed
    created_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                        ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_purchase_user       (user_id),
    KEY idx_purchase_book       (book_id),
    KEY idx_purchase_user_book  (user_id, book_id),
    CONSTRAINT fk_purchase_user FOREIGN KEY (user_id)
        REFERENCES users_tb (id) ON DELETE CASCADE,
    CONSTRAINT fk_purchase_book FOREIGN KEY (book_id)
        REFERENCES catalog_books_tb (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ── user_settings_tb ─────────────────────────────────────────────────────────
-- Global per-user reader defaults (not per-book).
-- The per-book prefs in user_books_tb override these.
-- Also stores UI preferences that don't belong on individual books.
--
CREATE TABLE IF NOT EXISTS user_settings_tb (
    user_id             INT UNSIGNED    NOT NULL,
    default_theme       VARCHAR(32)     DEFAULT 'dark',
    default_fontsize    SMALLINT UNSIGNED DEFAULT 385,
    default_fontfamily  VARCHAR(64)     DEFAULT 'georgia',
    default_spacing     VARCHAR(32)     DEFAULT 'normal',
    default_margins     VARCHAR(32)     DEFAULT 'normal',
    ui_language         VARCHAR(8)      DEFAULT 'en',
    auto_backup_epub    TINYINT(1)      DEFAULT 0,  -- upload local EPUBs automatically
    sync_enabled        TINYINT(1)      DEFAULT 1,
    updated_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                        ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id),
    CONSTRAINT fk_settings_user FOREIGN KEY (user_id)
        REFERENCES users_tb (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ═══════════════════════════════════════════════════════════════════════════════
-- Sync API design notes
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Endpoint pattern (mirrors airbuddy-ONLINE architecture):
--
--   POST /api/sync
--   Authorization: session cookie (airbuddy_sid equivalent)
--   Body: {
--     device_id: <int>,
--     last_sync_at: <ISO-8601 UTC>,          ← NULL on first sync
--     changes: {
--       user_books:     [ { book_id, read_percent, read_position, … } ],
--       bookmarks:      [ { local_id, book_id, cfi, pct, label, color,
--                           created_at, deleted_at } ],
--       highlights:     [ { local_id, book_id, cfi, text, color,
--                           created_at, deleted_at } ],
--       reading_lists:  [ { local_id, name, description, deleted_at } ],
--       list_entries:   [ { list_local_id, book_id, position, deleted_at } ]
--     }
--   }
--   Response: {
--     server_time: <ISO-8601 UTC>,
--     changes: { … same shape … }            ← rows changed since last_sync_at
--   }
--
-- Delta pull query pattern (same for all syncable tables):
--   SELECT * FROM <table>
--   WHERE user_id = :user_id
--     AND updated_at > :last_sync_at;
--
-- Conflict resolution (server-side):
--   • user_books: keep row with MAX(read_percent); on tie, MAX(updated_at).
--   • bookmarks / highlights / list_entries: INSERT … ON DUPLICATE KEY UPDATE
--     deleted_at = VALUES(deleted_at), updated_at = VALUES(updated_at).
--     A deleted_at from either side wins — once deleted, always deleted.
--
-- First sync (last_sync_at IS NULL):
--   Server returns full dataset; client merges with local data applying the
--   same conflict rules, then does a final push of any remaining local-only rows.
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- Seed data
-- ═══════════════════════════════════════════════════════════════════════════════

-- Bearthen store book: Tractatus Ayyew
INSERT IGNORE INTO catalog_books_tb
    (id, title, author_display, language, category, source, source_id,
     description, cover_url, store_price_cents, store_currency, store_epub_key)
VALUES
    ('bearthen_tractatus',
     'Tractatus Ayyew: Earthen Ethics',
     'Banayan Angway and Russell Maier',
     'en',
     'philosophy',
     'bearthen',
     'tractatus',
     'The foundational work of Earthen Ethics, grounded in the ecological wisdom '
     'of the Igorot people of Northern Luzon and the Global Ecobrick Alliance.',
     'https://book.earthen.io/assets/covers/tractatus-cover.jpg',
     1000,      -- $10.00 USD
     'USD',
     'protected/tractatus-ayyew.epub'
    );
