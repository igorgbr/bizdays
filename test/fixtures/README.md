# Official ANBIMA holiday fixture

`anbima_feriados.csv` contains one ISO date per line, without a header.
It is used only by tests; the library calculates its runtime calendar from rules.
Tests read this local snapshot and do not require network access or Python.

## Provenance

- Source: [ANBIMA bank holidays](https://www.anbima.com.br/feriados/feriados.asp).
- Download: [official XLS spreadsheet](https://www.anbima.com.br/feriados/arqs/feriados_nacionais.xls).
- Retrieved: 2026-10-01.
- Original XLS SHA-256: `e3070152bfbdd733a27977adc82b799e973d3ea003d2aa25b0e7e5bdae63aa17`.
- Worksheet: `Feriados`; first column (`Data`), using the workbook's Excel date system.
- Coverage: 2001–2099; 1,264 date rows, normalized to 1,263 unique dates.
- The spreadsheet lists 2079-04-21 twice: Good Friday and Tiradentes coincide.
  The CSV retains that date once, matching the calendar's set semantics.
- Header, blank rows and explanatory footer text are excluded. Weekend holidays
  are retained. No dates come from another library or from this project's formulas.

## Reproduce the conversion

Download the XLS from the link above. For this snapshot, verify its SHA-256
against the recorded value. A different hash means the source has changed and
requires review before replacing the fixture.

The following commands run from the project root. Python and `xlrd` are needed
only for conversion; they are not project or test dependencies.

```sh
python3 -m venv /tmp/bizdays-xls-env
/tmp/bizdays-xls-env/bin/pip install xlrd==2.0.2
curl --fail --location \
  https://www.anbima.com.br/feriados/arqs/feriados_nacionais.xls \
  --output /tmp/bizdays-feriados_nacionais.xls
sha256sum /tmp/bizdays-feriados_nacionais.xls

/tmp/bizdays-xls-env/bin/python - <<'PY'
from pathlib import Path
import xlrd

book = xlrd.open_workbook('/tmp/bizdays-feriados_nacionais.xls')
sheet = book.sheet_by_name('Feriados')
dates = []
for row in range(1, sheet.nrows):
    cell = sheet.cell(row, 0)
    if cell.ctype == xlrd.XL_CELL_DATE:
        date = xlrd.xldate_as_datetime(cell.value, book.datemode).date()
        assert 2001 <= date.year <= 2099
        dates.append(date.isoformat())

assert len(dates) == 1264
unique_dates = sorted(set(dates))
assert len(unique_dates) == 1263
assert {date[:4] for date in unique_dates} == {str(year) for year in range(2001, 2100)}
Path('test/fixtures/anbima_feriados.csv').write_text(
    '\n'.join(unique_dates) + '\n', encoding='utf-8'
)
PY

mix test test/bizdays/anbima_fixture_test.exs
```

When updating the snapshot, review changes in the official source, record the
new retrieval date and hash, and update the integrity counts if needed.
Investigate discrepancies before changing calendar rules or expected dates.
