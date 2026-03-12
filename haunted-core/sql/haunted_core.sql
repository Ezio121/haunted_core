CREATE TABLE IF NOT EXISTS hc_schema_migrations (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    version INT UNSIGNED NOT NULL,
    name VARCHAR(128) NOT NULL,
    applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_hc_schema_migrations_name (name),
    KEY idx_hc_schema_migrations_version (version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS users (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    license VARCHAR(80) NOT NULL,
    citizenid VARCHAR(32) NOT NULL,
    charname VARCHAR(100) NOT NULL DEFAULT '',
    firstname VARCHAR(60) NOT NULL DEFAULT '',
    lastname VARCHAR(60) NOT NULL DEFAULT '',
    dateofbirth DATE NULL,
    sex VARCHAR(12) NOT NULL DEFAULT 'U',
    nationality VARCHAR(50) NOT NULL DEFAULT 'Unknown',
    phone VARCHAR(32) NOT NULL DEFAULT '',
    job VARCHAR(60) NOT NULL DEFAULT 'unemployed',
    job_grade INT NOT NULL DEFAULT 0,
    `group` VARCHAR(60) NOT NULL DEFAULT 'none',
    position JSON NULL,
    metadata LONGTEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_seen TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_users_license (license),
    UNIQUE KEY uq_users_citizenid (citizenid),
    KEY idx_users_job (job),
    KEY idx_users_last_seen (last_seen)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS player_accounts (
    citizenid VARCHAR(32) NOT NULL,
    cash BIGINT NOT NULL DEFAULT 0,
    bank BIGINT NOT NULL DEFAULT 0,
    spirit_energy INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (citizenid),
    CONSTRAINT fk_player_accounts_user FOREIGN KEY (citizenid) REFERENCES users (citizenid) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS player_inventory (
    citizenid VARCHAR(32) NOT NULL,
    inventory LONGTEXT NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (citizenid),
    CONSTRAINT fk_player_inventory_user FOREIGN KEY (citizenid) REFERENCES users (citizenid) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS player_metadata (
    citizenid VARCHAR(32) NOT NULL,
    metadata LONGTEXT NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (citizenid),
    CONSTRAINT fk_player_metadata_user FOREIGN KEY (citizenid) REFERENCES users (citizenid) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS player_permissions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    identifier VARCHAR(80) NOT NULL,
    permission VARCHAR(50) NOT NULL,
    granted_by VARCHAR(80) NOT NULL DEFAULT 'system',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_player_permissions_identifier_permission (identifier, permission),
    KEY idx_player_permissions_identifier (identifier),
    KEY idx_player_permissions_permission (permission)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ghost_states (
    citizenid VARCHAR(32) NOT NULL,
    state ENUM('ALIVE', 'GHOST') NOT NULL DEFAULT 'ALIVE',
    spirit_energy INT NOT NULL DEFAULT 0,
    haunt_level INT NOT NULL DEFAULT 0,
    possession_state LONGTEXT NULL,
    last_transition_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (citizenid),
    KEY idx_ghost_states_state (state),
    KEY idx_ghost_states_updated_at (updated_at),
    CONSTRAINT fk_ghost_states_user FOREIGN KEY (citizenid) REFERENCES users (citizenid) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS jobs (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(60) NOT NULL,
    label VARCHAR(80) NOT NULL,
    is_default TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_jobs_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS job_grades (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    job_name VARCHAR(60) NOT NULL,
    grade INT NOT NULL,
    name VARCHAR(60) NOT NULL,
    label VARCHAR(80) NOT NULL,
    salary INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_job_grades_job_grade (job_name, grade),
    KEY idx_job_grades_job_name (job_name),
    CONSTRAINT fk_job_grades_job FOREIGN KEY (job_name) REFERENCES jobs (name) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS owned_entities (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    citizenid VARCHAR(32) NOT NULL,
    entity_type VARCHAR(40) NOT NULL,
    net_id INT NULL,
    metadata LONGTEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_owned_entities_citizenid (citizenid),
    KEY idx_owned_entities_type (entity_type),
    CONSTRAINT fk_owned_entities_user FOREIGN KEY (citizenid) REFERENCES users (citizenid) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    action VARCHAR(100) NOT NULL,
    source INT NOT NULL DEFAULT 0,
    citizenid VARCHAR(32) NULL,
    payload LONGTEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_audit_logs_action (action),
    KEY idx_audit_logs_source (source),
    KEY idx_audit_logs_citizenid (citizenid),
    KEY idx_audit_logs_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS server_kvp (
    kvp_key VARCHAR(128) NOT NULL,
    kvp_value LONGTEXT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (kvp_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO jobs (name, label, is_default) VALUES ('unemployed', 'Unemployed', 1);
INSERT IGNORE INTO job_grades (job_name, grade, name, label, salary) VALUES ('unemployed', 0, 'worker', 'Worker', 0);
