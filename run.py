"""표준 라이브러리만 사용하는 SQLite 실행·결과 저장 CLI. Python 3.10+."""
import argparse
import re
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parent

def render(cursor):
    if cursor.description is None:
        return f"affected_rows: {cursor.rowcount}\n"
    names = [col[0] for col in cursor.description]
    rows = cursor.fetchall()
    return '\t'.join(names) + '\n' + '\n'.join('\t'.join('NULL' if v is None else str(v) for v in row) for row in rows) + f'\n({len(rows)} rows)\n'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--db', default=str(ROOT / 'data' / 'drawer.db'), help='새로 만들 DB 경로; 기존 파일은 덮어쓰지 않습니다.')
    args = parser.parse_args()
    db = Path(args.db).resolve()
    if db.exists():
        parser.error('DB가 이미 있습니다. 기존 DB를 보존하려면 --db data/another.db 를 사용하세요.')
    db.parent.mkdir(parents=True, exist_ok=True)
    out = ROOT / 'results'
    out.mkdir(exist_ok=True)
    con = sqlite3.connect(db)
    try:
        for name in ('01_schema.sql', '02_seed.sql'):
            con.executescript((ROOT / 'sql' / name).read_text(encoding='utf-8'))
        assert con.execute('PRAGMA foreign_keys').fetchone()[0] == 1
        tables = ('genre','reader','novel','reading_log')
        before = {t: con.execute(f'SELECT COUNT(*) FROM {t}').fetchone()[0] for t in tables}
        assert before == {'genre':10,'reader':10,'novel':12,'reading_log':30}
        parts = re.split(r'(?m)^-- Q(\d{2}): ', (ROOT / 'sql/03_queries.sql').read_text(encoding='utf-8'))
        assert len(parts) == 31
        equivalence = {}
        for i in range(1,len(parts),2):
            num, block = parts[i:i+2]
            title, sql = block.strip().split('\n',1)
            extra = ''
            if num in ('13','14'):
                key = 1 if num == '13' else 30
                extra = '\nBEFORE\n' + render(con.execute('SELECT * FROM reading_log WHERE log_id=?',(key,)))
            cur = con.execute(sql)
            if num in ('08','12'):
                equivalence[num] = con.execute(sql).fetchall()
            result = render(cur)
            if num in ('13','14'):
                assert cur.rowcount == 1
                extra += '\nAFTER\n' + render(con.execute('SELECT * FROM reading_log WHERE log_id=?',(key,)))
            if num == '15':
                result = 'CREATE INDEX: success\n'
                extra = '\nINDEXES\n' + render(con.execute("PRAGMA index_list('reading_log')"))
                extra += '\nQUERY PLAN (SQLite EXPLAIN QUERY PLAN)\n' + render(con.execute("EXPLAIN QUERY PLAN SELECT * FROM reading_log WHERE read_on >= '2026-10-01' AND read_on < '2026-11-01'"))
            (out / f'q{num}.txt').write_text(f'Q{num}: {title}\n\nSQL\n{sql}\n\nRESULT\n{result}{extra}',encoding='utf-8')
        con.commit()
        assert equivalence['08'] == equivalence['12'] == [(11,'겨울 정원의 계약'),(12,'새벽의 연금술사')]
        assert con.execute('SELECT note FROM reading_log WHERE log_id=1').fetchone()[0] == '다음 회차도 읽고 싶은 작품'
        assert con.execute('SELECT COUNT(*) FROM reading_log WHERE log_id=30').fetchone()[0] == 0
        tests = [
            ('FK', "INSERT INTO novel VALUES (99,999,'없는 장르','테스트',10)"),
            ('UNIQUE', "INSERT INTO genre VALUES (99,'로맨스판타지')"),
            ('NOT NULL', "INSERT INTO reader VALUES (99,NULL,'test@example.com')"),
            ('CHECK', "INSERT INTO reading_log VALUES (99,1,1,'2026-10-25',0,10,3,'오류')"),
            ('RESTRICT', 'DELETE FROM reader WHERE reader_id=1')]
        evidence = ['SQLite '+sqlite3.sqlite_version, 'PRAGMA foreign_keys = 1','초기 행 수: '+str(before)]
        for name, sql in tests:
            con.execute('SAVEPOINT check_constraint')
            try:
                con.execute(sql)
            except sqlite3.IntegrityError as err:
                evidence.append(f'PASS {name}\nSQL: {sql}\n실제 오류: {err}')
            else:
                raise AssertionError(f'{name}: 잘못된 입력이 허용됨')
            finally:
                con.execute('ROLLBACK TO check_constraint')
                con.execute('RELEASE check_constraint')
        assert not con.execute('PRAGMA foreign_key_check').fetchall()
        assert con.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
        after = {t:con.execute(f'SELECT COUNT(*) FROM {t}').fetchone()[0] for t in tables}
        assert after == {'genre':10,'reader':10,'novel':12,'reading_log':29}
        evidence += ['최종 행 수: '+str(after),'PASS Q08 = Q12','PASS UPDATE / DELETE','PASS foreign_key_check / integrity_check']
        (out/'validation.txt').write_text('\n\n'.join(evidence)+'\n',encoding='utf-8')
        print('완료: '+str(db))
        print('쿼리 15개 실행 및 제약조건 검증 통과. 결과: '+str(out))
    finally:
        con.close()

if __name__ == '__main__':
    main()
