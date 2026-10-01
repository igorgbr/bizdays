defmodule Bizdays.AdjustmentsAndRangesTest do
  use ExUnit.Case, async: true

  alias Bizdays.ANBIMA
  alias Bizdays.Calendar

  test "modified adjustments reverse direction at month and year changes" do
    calendar = Bizdays.anbima()

    assert Bizdays.following(calendar, ~D[2026-01-31]) == ~D[2026-02-02]
    assert Bizdays.modified_following(calendar, ~D[2026-01-31]) == ~D[2026-01-30]
    assert Bizdays.modified_preceding(calendar, ~D[2026-03-01]) == ~D[2026-03-02]
    assert Bizdays.modified_following(calendar, ~D[2023-12-31]) == ~D[2023-12-29]
    assert Bizdays.modified_preceding(calendar, ~D[2026-01-01]) == ~D[2026-01-02]
  end

  test "modified adjustments preserve business days and ordinary same-month adjustments" do
    calendar = Bizdays.anbima()

    assert Bizdays.modified_following(calendar, ~D[2026-02-16]) == ~D[2026-02-18]
    assert Bizdays.modified_preceding(calendar, ~D[2026-02-16]) == ~D[2026-02-13]

    for operation <- [&Bizdays.modified_following/2, &Bizdays.modified_preceding/2] do
      assert operation.(calendar, ~D[2026-02-18]) == ~D[2026-02-18]
    end
  end

  test "modified adjustments respect custom weekends and holidays" do
    calendar = Calendar.new(weekend: [5, 6], holidays: [~D[2026-01-29]])

    assert Bizdays.modified_following(calendar, ~D[2026-01-30]) == ~D[2026-01-28]
    assert Bizdays.modified_preceding(calendar, ~D[2026-05-01]) == ~D[2026-05-03]
  end

  test "a month without business days uses the opposite adjustment" do
    calendar = Calendar.new(holidays: Enum.to_list(Date.range(~D[2026-02-01], ~D[2026-02-28])))

    assert Bizdays.modified_following(calendar, ~D[2026-02-16]) == ~D[2026-01-30]
    assert Bizdays.modified_preceding(calendar, ~D[2026-02-16]) == ~D[2026-03-02]
  end

  test "modified adjustments raise when the initial or fallback search hits a boundary" do
    for {operation, first, last, date} <- [
          {&Bizdays.modified_following/2, ~D[2026-01-30], ~D[2026-01-31], ~D[2026-01-31]},
          {&Bizdays.modified_preceding/2, ~D[2026-03-01], ~D[2026-03-02], ~D[2026-03-01]},
          {&Bizdays.modified_following/2, ~D[2026-01-31], ~D[2026-02-02], ~D[2026-01-31]},
          {&Bizdays.modified_preceding/2, ~D[2026-02-27], ~D[2026-03-01], ~D[2026-03-01]}
        ] do
      calendar = Calendar.new(first_date: first, last_date: last)
      assert_raise ArgumentError, ~r/calendar boundary/, fn -> operation.(calendar, date) end
    end
  end

  test "range includes business-day endpoints and preserves direction" do
    calendar = Bizdays.anbima()
    expected = [~D[2026-02-13], ~D[2026-02-18], ~D[2026-02-19]]

    assert Bizdays.range(calendar, ~D[2026-02-13], ~D[2026-02-19]) == expected
    assert Bizdays.range(calendar, ~D[2026-02-19], ~D[2026-02-13]) == Enum.reverse(expected)
    assert Bizdays.range(calendar, ~D[2026-02-14], ~D[2026-02-18]) == [~D[2026-02-18]]
    assert Bizdays.range(calendar, ~D[2026-02-14], ~D[2026-02-17]) == []
    assert Bizdays.range(calendar, ~D[2026-02-17], ~D[2026-02-14]) == []
    assert Bizdays.range(calendar, ~D[2026-02-13], ~D[2026-02-13]) == [~D[2026-02-13]]
    assert Bizdays.range(calendar, ~D[2026-02-16], ~D[2026-02-16]) == []
  end

  test "range respects custom weekends, holidays and inclusive calendar limits" do
    calendar =
      Calendar.new(
        weekend: [],
        holidays: [~D[2024-02-29]],
        first_date: ~D[2024-02-28],
        last_date: ~D[2024-03-02]
      )

    assert Bizdays.range(calendar, calendar.first_date, calendar.last_date) ==
             [~D[2024-02-28], ~D[2024-03-01], ~D[2024-03-02]]

    closed = Calendar.new(weekend: Enum.to_list(1..7))
    assert Bizdays.range(closed, ~D[2026-01-01], ~D[2026-01-31]) == []
  end

  test "holidays uses the supplied calendar and includes weekend holidays" do
    assert Bizdays.holidays(Bizdays.anbima(), 2026) == ANBIMA.holidays(2026)
    assert ~D[2023-01-01] in Bizdays.holidays(Bizdays.anbima(), 2023)
    assert Bizdays.holidays(Calendar.new(), 2026) == []

    custom =
      Calendar.new(holidays: [~D[2026-12-25], ~D[2025-12-25], ~D[2026-01-25], ~D[2026-01-25]])

    assert Bizdays.holidays(custom, 2026) == [~D[2026-01-25], ~D[2026-12-25]]
  end

  test "holidays accepts partially covered years and rejects years outside the calendar" do
    calendar =
      Calendar.new(
        first_date: ~D[2026-06-01],
        last_date: ~D[2027-02-01],
        holidays: [~D[2026-12-25], ~D[2027-01-01]]
      )

    assert Bizdays.holidays(calendar, 2026) == [~D[2026-12-25]]
    assert Bizdays.holidays(calendar, 2027) == [~D[2027-01-01]]

    for year <- [2000, 2025, 2028, 2100, 2026.0, "2026", nil] do
      assert_raise ArgumentError, fn -> Bizdays.holidays(calendar, year) end
    end
  end

  test "validates dates before adjustments and enumeration" do
    calendar = Calendar.new(first_date: ~D[2026-01-01], last_date: ~D[2026-12-31])

    for date <- [
          ~D[2025-12-31],
          ~D[2027-01-01],
          "2026-01-01",
          nil,
          ~N[2026-01-01 00:00:00],
          ~U[2026-01-01 00:00:00Z],
          %Date{year: 2026, month: 2, day: 30},
          %Date{year: 2026, month: 1, day: 1, calendar: __MODULE__}
        ] do
      for operation <- [&Bizdays.modified_following/2, &Bizdays.modified_preceding/2] do
        assert_raise ArgumentError, fn -> operation.(calendar, date) end
      end

      for {from, to} <- [{date, ~D[2026-01-01]}, {~D[2026-01-01], date}, {date, date}] do
        assert_raise ArgumentError, fn -> Bizdays.range(calendar, from, to) end
      end
    end
  end
end
