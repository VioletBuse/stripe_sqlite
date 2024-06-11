-- initial_migration

CREATE TABLE IF NOT EXISTS paths (
    id TEXT NOT NULL PRIMARY KEY,
    path TEXT NOT NULL,
    to_fetch INT NOT NULL,
    created_at INT NOT NULL
);

CREATE TABLE IF NOT EXISTS path_fetch_results (
    id TEXT NOT NULL PRIMARY KEY,
    json TEXT NOT NULL,
    path_id TEXT NOT NULL REFERENCES paths(id),
    fetched_at INT NOT NULL
);
