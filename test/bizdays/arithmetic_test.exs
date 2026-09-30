defmodule Bizdays.ArithmeticTest do
  use ExUnit.Case, async: true

  alias Bizdays.Calendar

  test "adds positive and negative offsets across Carnival" do
    calendar = Bizdays.anbima()

    assert Bizdays.add(calendar, ~D[2026-02-13], 1) == ~D[2026-02-18]
    assert Bizdays.add(calendar, ~D[2026-02-13], 2) == ~D[2026-02-19]
    assert Bizdays.add(calendar, ~D[2026-02-18], -1) == ~D[2026-02-13]
    assert Bizdays.add(calendar, ~D[2026-02-18], -2) == ~D[2026-02-12]

    for date <- Date.range(~D[2026-02-14], ~D[2026-02-17]) do
      assert Bizdays.add(calendar, date, 1) == ~D[2026-02-18]
      assert Bizdays.add(calendar, date, -1) == ~D[2026-02-13]
      assert Bizdays.add(calendar, date, 0) == ~D[2026-02-18]
    end

    assert Bizdays.add(calendar, ~D[2026-02-13], 0) == ~D[2026-02-13]
  end

  test "counts explicit endpoints, reversed intervals and empty intervals" do
    calendar = Bizdays.anbima()

    for {from, to, expected} <- [
          {~D[2012-12-31], ~D[2013-01-03], 2},
          {~D[2026-02-13], ~D[2026-02-16], 0},
          {~D[2026-02-16], ~D[2026-02-18], 1},
          {~D[2026-02-14], ~D[2026-02-17], 0},
          {~D[2026-02-15], ~D[2026-02-22], 3},
          {~D[2026-02-13], ~D[2026-02-13], 0},
          {~D[2026-02-16], ~D[2026-02-16], 0},
          {~D[2024-02-28], ~D[2024-03-01], 2}
        ] do
      assert Bizdays.count(calendar, from, to) == expected
      assert Bizdays.count(calendar, to, from) == -expected
    end
  end

  test "does not subtract weekend holidays twice" do
    calendar = Calendar.new(holidays: [~D[2026-02-14], ~D[2026-02-16]])
    assert Bizdays.count(calendar, ~D[2026-02-13], ~D[2026-02-20]) == 4
  end

  test "handles custom weekends, no weekends and no business days" do
    custom = Calendar.new(weekend: [5, 6], holidays: [~D[2026-02-15]])
    assert Bizdays.add(custom, ~D[2026-02-12], 1) == ~D[2026-02-16]
    assert Bizdays.add(custom, ~D[2026-02-16], -1) == ~D[2026-02-12]
    assert Bizdays.count(custom, ~D[2026-02-12], ~D[2026-02-19]) == 4

    daily = Calendar.new(weekend: [])
    assert Bizdays.add(daily, ~D[2024-02-28], 2) == ~D[2024-03-01]
    assert Bizdays.count(daily, ~D[2024-02-28], ~D[2024-03-01]) == 2

    closed =
      Calendar.new(
        weekend: Enum.to_list(1..7),
        first_date: ~D[2026-02-13],
        last_date: ~D[2026-02-20]
      )

    assert Bizdays.count(closed, closed.first_date, closed.last_date) == 0

    for n <- [-1, 0, 1] do
      assert_raise ArgumentError, fn -> Bizdays.add(closed, ~D[2026-02-16], n) end
    end
  end

  test "accepts exact boundaries and rejects offsets beyond them" do
    calendar = Calendar.new(first_date: ~D[2026-02-13], last_date: ~D[2026-02-16])

    assert Bizdays.add(calendar, calendar.first_date, 1) == calendar.last_date
    assert Bizdays.add(calendar, calendar.last_date, -1) == calendar.first_date
    assert Bizdays.count(calendar, calendar.first_date, calendar.last_date) == 1

    for {date, n} <- [
          {calendar.first_date, -1},
          {calendar.last_date, 1},
          {calendar.first_date, 2},
          {calendar.last_date, -2}
        ] do
      assert_raise ArgumentError, ~r/calendar boundary/, fn ->
        Bizdays.add(calendar, date, n)
      end
    end

    closed_end = Calendar.new(first_date: ~D[2026-02-13], last_date: ~D[2026-02-15])
    assert_raise ArgumentError, fn -> Bizdays.add(closed_end, ~D[2026-02-15], 0) end
  end

  test "rejects invalid offsets and dates, including zero and equal endpoints" do
    calendar = Bizdays.anbima()

    for n <- [1.0, "1", nil] do
      assert_raise ArgumentError, ~r/integer business day offset/, fn ->
        Bizdays.add(calendar, ~D[2026-02-13], n)
      end
    end

    for date <- [
          ~D[2000-12-31],
          ~D[2100-01-01],
          ~N[2026-01-01 00:00:00],
          ~U[2026-01-01 00:00:00Z],
          "2026-01-01",
          nil,
          %Date{year: 2026, month: 2, day: 30},
          %Date{year: 2026, month: 1, day: 1, calendar: __MODULE__}
        ] do
      for n <- [-1, 0, 1] do
        assert_raise ArgumentError, fn -> Bizdays.add(calendar, date, n) end
      end

      for {from, to} <- [{date, ~D[2026-01-01]}, {~D[2026-01-01], date}, {date, date}] do
        assert_raise ArgumentError, fn -> Bizdays.count(calendar, from, to) end
      end
    end
  end

  test "optimized count matches daily enumeration for different week patterns" do
    for weekend <- [[], [7], [5, 6], [6, 7], Enum.to_list(1..7)] do
      calendar = Calendar.new(weekend: weekend, holidays: [~D[2024-02-29], ~D[2024-03-03]])

      for start_offset <- 0..6, length <- 0..21 do
        from = Date.add(~D[2024-02-25], start_offset)
        to = Date.add(from, length)
        expected = enumerated_count(calendar, from, to)

        assert Bizdays.count(calendar, from, to) == expected
        assert Bizdays.count(calendar, to, from) == -expected
      end
    end
  end

  test "counts the entire ANBIMA interval against daily enumeration" do
    calendar = Bizdays.anbima()
    expected = enumerated_count(calendar, calendar.first_date, calendar.last_date)

    assert Bizdays.count(calendar, calendar.first_date, calendar.last_date) == expected
    assert Bizdays.count(calendar, calendar.last_date, calendar.first_date) == -expected
  end

  test "count and add agree for business-day starts and signed offsets" do
    calendar = Bizdays.anbima()

    for date <- Date.range(~D[2026-01-01], ~D[2026-12-31], 7),
        Bizdays.business_day?(calendar, date),
        n <- [-20, -5, -1, 0, 1, 5, 20] do
      result = Bizdays.add(calendar, date, n)

      assert Bizdays.business_day?(calendar, result)
      assert Bizdays.count(calendar, date, result) == n
      assert Bizdays.add(calendar, result, -n) == date
    end
  end

  defp enumerated_count(calendar, from, to) do
    from
    |> Date.range(to)
    |> Enum.count(&(&1 != from and Bizdays.business_day?(calendar, &1)))
  end
end
