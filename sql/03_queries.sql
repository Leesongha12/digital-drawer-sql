-- SQLite용. 01 → 02 → 03 순서로 실행. Q13/Q14는 실제 데이터를 변경합니다.
-- 최초 실행 시 기록 30행 → 29행. 재실행의 동일 결과는 새 DB에서만 보장됩니다.
PRAGMA foreign_keys = ON;

-- Q01: 기본 조회: 평점 4점 이상인 독서 기록
SELECT log_id, reader_id, novel_id, rating FROM reading_log WHERE rating >= 4 ORDER BY log_id;

-- Q02: 기본 조회: 회차 수가 많은 작품 TOP 5
SELECT novel_id, title, total_episodes FROM novel ORDER BY total_episodes DESC, novel_id LIMIT 5;

-- Q03: 기본 조회: 제목에 마법이 들어간 작품
SELECT novel_id, title, author FROM novel WHERE title LIKE '%마법%' ORDER BY novel_id;

-- Q04: 기본 조회: 2026년 10월 독서 기록
SELECT log_id, read_on, episodes_read FROM reading_log WHERE read_on >= '2026-10-01' AND read_on < '2026-11-01' ORDER BY read_on, log_id;

-- Q05: INNER JOIN: 작품과 장르
SELECT n.novel_id, n.title, g.name AS genre FROM novel n INNER JOIN genre g ON n.genre_id=g.genre_id ORDER BY n.novel_id;

-- Q06: INNER JOIN: 독자별 기록 상세
SELECT l.log_id, r.nickname, n.title, l.read_on, l.episodes_read FROM reading_log l INNER JOIN reader r ON l.reader_id=r.reader_id INNER JOIN novel n ON l.novel_id=n.novel_id ORDER BY l.log_id;

-- Q07: LEFT JOIN: 기록이 없는 독자를 포함한 독자별 기록 수
SELECT r.reader_id, r.nickname, COUNT(l.log_id) AS log_count FROM reader r LEFT JOIN reading_log l ON r.reader_id=l.reader_id GROUP BY r.reader_id, r.nickname ORDER BY r.reader_id;

-- Q08: LEFT JOIN: 독서 기록이 없는 작품
SELECT n.novel_id, n.title FROM novel n LEFT JOIN reading_log l ON n.novel_id=l.novel_id WHERE l.log_id IS NULL ORDER BY n.novel_id;

-- Q09: 집계: 독자별 읽은 분량과 시간
SELECT reader_id, COUNT(*) AS sessions, SUM(episodes_read) AS episodes, SUM(minutes_spent) AS minutes FROM reading_log GROUP BY reader_id ORDER BY episodes DESC, reader_id;

-- Q10: 집계: 작품별 평균 평점과 평가 수(NULL 제외)
SELECT novel_id, COUNT(rating) AS rating_count, ROUND(AVG(rating),2) AS avg_rating FROM reading_log GROUP BY novel_id ORDER BY avg_rating DESC, novel_id;

-- Q11: 집계: 월별 독서량 — SUBSTR로 ISO 날짜에서 연월 추출
SELECT SUBSTR(read_on,1,7) AS month, COUNT(*) AS sessions, SUM(episodes_read) AS episodes FROM reading_log GROUP BY SUBSTR(read_on,1,7) ORDER BY month;

-- Q12: 서브쿼리: 독서 기록이 없는 작품(Q08과 동일 요구)
SELECT n.novel_id, n.title FROM novel n WHERE NOT EXISTS (SELECT 1 FROM reading_log l WHERE l.novel_id=n.novel_id) ORDER BY n.novel_id;

-- Q13: UPDATE: 1번 기록의 메모 수정
UPDATE reading_log SET note='다음 회차도 읽고 싶은 작품' WHERE log_id=1;

-- Q14: DELETE: 잘못 입력했다고 가정한 30번 기록 삭제
DELETE FROM reading_log WHERE log_id=30;

-- Q15: 인덱스: 날짜 범위 조회(Q04)의 전체 스캔 비용을 줄이기 위한 날짜 인덱스
CREATE INDEX IF NOT EXISTS idx_reading_log_read_on ON reading_log(read_on);
