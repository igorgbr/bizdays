# Bizdays

Business day calculations in Elixir, with the Brazilian ANBIMA calendar for
2001–2099 and support for custom calendars.

Pure functions over an immutable calendar struct. ANBIMA holidays are calculated
once at compile time. The library has zero runtime dependencies.

## Installation

Requires Elixir 1.15 or later. Until the first Hex release, use the Git repository:

```elixir
def deps do
  [
    {:bizdays, git: "https://github.com/igorgbr/bizdays.git"}
  ]
end
```

Run `mix deps.get`. Your application's `mix.lock` records the selected Git commit.

## Quick start

```elixir
cal = Bizdays.anbima()

Bizdays.business_day?(cal, ~D[2026-02-16])
# => false (Carnival)

Bizdays.following(cal, ~D[2026-02-16])
# => ~D[2026-02-18]

Bizdays.preceding(cal, ~D[2026-02-16])
# => ~D[2026-02-13]

Bizdays.add(cal, ~D[2026-02-13], 5)
# => ~D[2026-02-24]

Bizdays.count(cal, ~D[2026-02-13], ~D[2026-02-24])
# => 5
```

All calendar operations take the calendar first and support pipes:

```elixir
Bizdays.anbima() |> Bizdays.add(~D[2026-02-13], 1)
# => ~D[2026-02-18]
```

## Counting and adding business days

`Bizdays.count/3` counts **(from, to]**: the starting date is excluded and the
ending date is included if it is a business day. Endpoints are not adjusted.
Equal dates return zero. Reversing the dates reverses the sign.

```elixir
Bizdays.count(cal, ~D[2012-12-31], ~D[2013-01-03])
# => 2 (January 2 and 3)

Bizdays.count(cal, ~D[2013-01-03], ~D[2012-12-31])
# => -2

Bizdays.count(cal, ~D[2026-02-13], ~D[2026-02-17])
# => 0 (weekend and Carnival)

Bizdays.count(cal, ~D[2026-02-16], ~D[2026-02-18])
# => 1
```

`Bizdays.add/3` takes an integer offset. Positive values count business days
strictly after the starting date; negative values count strictly before it.
This also applies when the starting date is a holiday or weekend.
Zero returns `Bizdays.following/2`.

```elixir
Bizdays.add(cal, ~D[2026-02-16], 1)
# => ~D[2026-02-18]

Bizdays.add(cal, ~D[2026-02-16], -1)
# => ~D[2026-02-13]

Bizdays.add(cal, ~D[2026-02-16], 0)
# => ~D[2026-02-18]
```

For a business-day start `d`, `Bizdays.count(cal, d, Bizdays.add(cal, d, n)) == n`
when the result stays within the calendar boundaries.

The API draws inspiration from [python-bizdays](https://github.com/wilsonfreitas/python-bizdays).
Zero offsets adjust forward here, and the explicit counting convention can
differ when endpoints are not business days.

## Date adjustments and lists

| Function | Behavior |
| --- | --- |
| `Bizdays.following/2` | First business day on or after the date. |
| `Bizdays.preceding/2` | Last business day on or before the date. |
| `Bizdays.modified_following/2` | Following, switching to preceding if the result changes month. |
| `Bizdays.modified_preceding/2` | Preceding, switching to following if the result changes month. |
| `Bizdays.range/3` | List of business days, including both endpoints when they are business days. |
| `Bizdays.holidays/2` | Sorted holiday dates in a year, including holidays on weekends. |

```elixir
Bizdays.modified_following(cal, ~D[2026-01-31])
# => ~D[2026-01-30]

Bizdays.modified_preceding(cal, ~D[2026-03-01])
# => ~D[2026-03-02]

Bizdays.range(cal, ~D[2026-02-13], ~D[2026-02-19])
# => [~D[2026-02-13], ~D[2026-02-18], ~D[2026-02-19]]

Bizdays.range(cal, ~D[2026-02-19], ~D[2026-02-13])
# => [~D[2026-02-19], ~D[2026-02-18], ~D[2026-02-13]]

Bizdays.holidays(cal, 2026) |> Enum.take(3)
# => [~D[2026-01-01], ~D[2026-02-16], ~D[2026-02-17]]
```

`range/3` includes the starting date when it is a business day; `count/3` excludes it.
For equal endpoints, the range contains that date if it is a business day,
otherwise `[]`.

Modified adjustments require each search to succeed within the calendar limits.
Reaching a boundary raises an error. If a custom calendar has no business days
in a month, the fallback adjustment can also leave that month.

## Custom calendars

`Bizdays.Calendar.new/1` defaults to no holidays, Saturday/Sunday weekends,
and inclusive boundaries of 2001-01-01 and 2099-12-31. Weekdays use ISO numbers:
Monday is 1 and Sunday is 7. An empty weekend list makes every weekday available.

```elixir
custom = Bizdays.Calendar.new(
  name: "Custom",
  holidays: [~D[2026-02-18]],
  weekend: [6, 7],
  first_date: ~D[2026-01-01],
  last_date: ~D[2026-12-31]
)

Bizdays.following(custom, ~D[2026-02-18])
# => ~D[2026-02-19]
```

To extend ANBIMA, include its holidays explicitly:

```elixir
custom = Bizdays.Calendar.new(
  name: "ANBIMA + local holiday",
  holidays: MapSet.put(cal.holidays, ~D[2026-02-18])
)

Bizdays.following(custom, ~D[2026-02-16])
# => ~D[2026-02-19]
```

Holidays can be a list or `MapSet`. Duplicate dates are removed. Custom boundaries
must stay within 2001–2099, and all supplied holidays must lie within them.
For a partially covered year, `holidays/2` returns only the available holidays.

## ANBIMA coverage

The rules follow the [official ANBIMA calendar](https://www.anbima.com.br/feriados/feriados.asp):
national holidays affecting bank reserves, plus Carnival Monday and Tuesday,
Good Friday and Corpus Christi. November 20 is included from 2024, following
[Law 14,759/2023](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2023/lei/l14759.htm).

Maundy Thursday is a business day in the supported interval. Weekend holidays
stay on their original dates. Municipal/state holidays, elections and the
year-end bank closure are excluded. B3 trading holidays require a separate calendar.

The test suite compares all 1,263 unique holiday dates against a snapshot of
ANBIMA's official spreadsheet. The snapshot and its provenance are in
[test/fixtures](https://github.com/igorgbr/bizdays/tree/main/test/fixtures).
Future legal changes require a library update.

## Errors and limits

Operations accept ISO `Date` values, such as `~D[2026-02-13]`, and raise
`ArgumentError` for invalid dates or dates outside the calendar boundaries.
Strings, `DateTime` and `NaiveDateTime` are not accepted. A search or offset
that cannot find a business day within the boundaries also raises.

## Development

```sh
mix deps.get
mix format
mix test
mix credo --strict
mix docs --warnings-as-errors
```

Open `doc/index.html` for the generated documentation. The tests run offline,
including the official holiday fixture. CI tests Elixir/OTP 1.15/26, 1.17/27
and 1.20/29, with formatting, Credo and documentation checks on the last pair.

## License

[MIT](https://github.com/igorgbr/bizdays/blob/main/LICENSE) — Igor Giamoniano.
