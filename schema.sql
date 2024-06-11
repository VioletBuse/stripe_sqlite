CREATE TABLE storch_migrations (id integer, applied integer);

CREATE TABLE paths (
    id TEXT NOT NULL PRIMARY KEY,
    path TEXT NOT NULL,
    to_fetch INT NOT NULL,
    created_at INT NOT NULL
);

CREATE TABLE path_fetch_results (
    id TEXT NOT NULL PRIMARY KEY,
    json TEXT NOT NULL,
    path_id TEXT NOT NULL REFERENCES paths(id),
    fetched_at INT NOT NULL
);

