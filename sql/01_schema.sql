-- SQLite 전용: FK는 접속마다 활성화해야 한다. 트랜잭션 시작 전에 실행한다.
PRAGMA foreign_keys = ON;
BEGIN;
CREATE TABLE genre (
    genre_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);
CREATE TABLE reader (
    reader_id INTEGER PRIMARY KEY,
    nickname TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE
);
CREATE TABLE novel (
    novel_id INTEGER PRIMARY KEY,
    genre_id INTEGER NOT NULL REFERENCES genre(genre_id) ON DELETE RESTRICT,
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    total_episodes INTEGER NOT NULL CHECK(total_episodes > 0),
    UNIQUE(title, author)
);
-- 한 행은 한 독자가 특정 날짜에 읽은 분량(독서 세션)이다.
-- 동일 작품을 다시 읽을 수 있어 독자/작품 조합은 UNIQUE가 아니다.
CREATE TABLE reading_log (
    log_id INTEGER PRIMARY KEY,
    reader_id INTEGER NOT NULL REFERENCES reader(reader_id) ON DELETE RESTRICT,
    novel_id INTEGER NOT NULL REFERENCES novel(novel_id) ON DELETE RESTRICT,
    read_on TEXT NOT NULL CHECK(length(read_on)=10 AND read_on GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
    episodes_read INTEGER NOT NULL CHECK(episodes_read > 0),
    minutes_spent INTEGER NOT NULL CHECK(minutes_spent > 0),
    rating INTEGER CHECK(rating BETWEEN 1 AND 5),
    note TEXT NOT NULL DEFAULT ''
);
-- SQLite는 날짜를 TEXT ISO 8601(YYYY-MM-DD)로 저장한다.
-- GLOB은 SQLite 문법이며 형식만 검사한다. 실제 달력 날짜 검증은 입력자가 담당한다.
COMMIT;
