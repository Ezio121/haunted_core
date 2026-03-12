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
