"""
This script was used to dump the wiki contents of the Wiki.js database
To use it, just change the "dbname=[db] user=[user]" string below
The files will be saved to the current working directory
"""

import psycopg2
import os

QUERY = """
SELECT p.path, p."localeCode", format(E'+++\ntitle = "%s"\ndescription = "%s"\ndate = %s\ntags = %s\n+++\n\n%s', p.title, p.description, trim(both '"' from to_json(p."createdAt")::TEXT), json_agg(t.title), p.content) 
FROM pages p, "pageTags" s, tags t 
WHERE s."pageId" = P.id AND t.id = s."tagId" GROUP BY p.id;
"""

conn = psycopg2.connect("dbname=[db] user=[user]")
cur = conn.cursor()
cur.execute(QUERY)
results = cur.fetchall()
for path, locale, content in results:
    if locale:
        path = os.path.join(locale, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path + '.md', 'wt') as f:
        f.write(content)

cur.close()
conn.close()
