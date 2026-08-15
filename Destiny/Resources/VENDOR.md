# GeoNamesCities.db provenance

Built from GeoNames (https://www.geonames.org), CC BY 4.0 -- see the About
screen for the in-app attribution this requires.

Source files (pulled 2026-08-14):
- https://download.geonames.org/export/dump/cities1000.zip (170,687 places, population >= 1000)
- https://download.geonames.org/export/dump/admin1CodesASCII.txt (state/province names)
- https://download.geonames.org/export/dump/countryInfo.txt (country names)

Built into a single SQLite db with 3 tables (`cities`, `admin1`,
`countries`), trimmed to just the columns the app uses -- the
`alternatenames` column (by far the largest field in the raw dump) is
dropped since search only needs the primary name. Indexed on
`cities.ascii_name COLLATE NOCASE` for prefix search and
`cities.population DESC` for ranking. Final size ~17.6MB, vs. cities5000
(population >= 5000) at ~7MB -- cities1000 was chosen deliberately since
someone's actual birthplace is often a small town, not a major city.

Do not hand-edit GeoNamesCities.db -- regenerate from a fresh GeoNames
pull if the data needs updating. Build steps (run from a scratch
directory with `sqlite3` available):

```bash
curl -sLO https://download.geonames.org/export/dump/cities1000.zip
curl -sLO https://download.geonames.org/export/dump/admin1CodesASCII.txt
curl -sLO https://download.geonames.org/export/dump/countryInfo.txt
unzip cities1000.zip

awk -F'\t' 'BEGIN{OFS="\t"}{print $2,$3,$9,$11,$5,$6,$15,$18}' \
  cities1000.txt > cities1000_trimmed.tsv
grep -v '^#' countryInfo.txt | awk -F'\t' 'BEGIN{OFS="\t"}{print $1,$5}' \
  > countries_trimmed.tsv

sqlite3 GeoNamesCities.db <<'SQL'
CREATE TABLE cities (name TEXT, ascii_name TEXT, country_code TEXT,
  admin1_code TEXT, latitude REAL, longitude REAL, population INTEGER,
  timezone TEXT);
CREATE TABLE admin1 (code TEXT PRIMARY KEY, name TEXT);
CREATE TABLE admin1_stage (code TEXT, name TEXT, ascii_name TEXT, geonameid TEXT);
CREATE TABLE countries (code TEXT PRIMARY KEY, name TEXT);
.mode tabs
.import cities1000_trimmed.tsv cities
.import admin1CodesASCII.txt admin1_stage
.import countries_trimmed.tsv countries
INSERT INTO admin1 (code, name) SELECT code, name FROM admin1_stage;
DROP TABLE admin1_stage;
CREATE INDEX idx_ascii_prefix ON cities(ascii_name COLLATE NOCASE);
CREATE INDEX idx_population ON cities(population DESC);
VACUUM;
SQL
```
