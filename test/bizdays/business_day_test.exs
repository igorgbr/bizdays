defmodule Bizdays.BusinessDayTest do
  use ExUnit.Case, async: true

  alias Bizdays.Calendar

  test "recognizes ANBIMA holidays, weekends and business days" do
    calendar = Bizdays.anbima()

    for date <- [~D[2026-02-14], ~D[2026-02-15], ~D[2026-02-16], ~D[2026-02-17]] do
      refute Bizdays.business_day?(calendar, date)
    end

    assert Bizdays.business_day?(calendar, ~D[2026-02-18])
    assert Bizdays.business_day?(calendar, ~D[2026-04-02])
    assert Bizdays.business_day?(calendar, ~D[2023-11-20])
    refute Bizdays.business_day?(calendar, ~D[2024-11-20])
  end

  test "adjusts across Carnival and keeps business days unchanged" do
    calendar = Bizdays.anbima()

    for date <- Date.range(~D[2026-02-14], ~D[2026-02-17]) do
      assert Bizdays.following(calendar, date) == ~D[2026-02-18]
      assert Bizdays.preceding(calendar, date) == ~D[2026-02-13]
    end

    assert Bizdays.following(calendar, ~D[2026-02-13]) == ~D[2026-02-13]
    assert Bizdays.preceding(calendar, ~D[2026-02-18]) == ~D[2026-02-18]
  end

  test "adjusts across year and leap-day boundaries" do
    calendar = Bizdays.anbima()

    assert Bizdays.preceding(calendar, ~D[2026-01-01]) == ~D[2025-12-31]
    assert Bizdays.following(calendar, ~D[2023-12-31]) == ~D[2024-01-02]
    assert Bizdays.preceding(calendar, ~D[2020-03-01]) == ~D[2020-02-28]
    assert Bizdays.following(calendar, ~D[2020-02-29]) == ~D[2020-03-02]
  end

  test "respects custom holidays and weekend definitions" do
    calendar = Calendar.new(weekend: [5, 6], holidays: [~D[2026-02-15]])

    refute Bizdays.business_day?(calendar, ~D[2026-02-13])
    refute Bizdays.business_day?(calendar, ~D[2026-02-15])
    assert Bizdays.following(calendar, ~D[2026-02-13]) == ~D[2026-02-16]
    assert Bizdays.preceding(calendar, ~D[2026-02-15]) == ~D[2026-02-12]
    assert Bizdays.business_day?(Calendar.new(), ~D[2026-02-16])
    assert Bizdays.business_day?(Calendar.new(weekend: []), ~D[2026-02-15])
  end

  test "finds business days exactly on either inclusive boundary" do
    calendar = Calendar.new(first_date: ~D[2026-02-13], last_date: ~D[2026-02-16])

    assert Bizdays.preceding(calendar, ~D[2026-02-15]) == calendar.first_date
    assert Bizdays.following(calendar, ~D[2026-02-14]) == calendar.last_date

    single_day = Calendar.new(first_date: ~D[2026-02-13], last_date: ~D[2026-02-13])
    assert Bizdays.business_day?(single_day, single_day.first_date)
    assert Bizdays.following(single_day, single_day.first_date) == single_day.first_date
    assert Bizdays.preceding(single_day, single_day.first_date) == single_day.first_date
  end

  test "fails when the search direction has no available business day" do
    calendar = Calendar.new(first_date: ~D[2026-02-14], last_date: ~D[2026-02-21])

    assert_raise ArgumentError, ~r/no business day.*boundary/, fn ->
      Bizdays.preceding(calendar, ~D[2026-02-15])
    end

    assert_raise ArgumentError, ~r/no business day.*boundary/, fn ->
      Bizdays.following(calendar, ~D[2026-02-21])
    end

    assert_raise ArgumentError, ~r/no business day.*boundary/, fn ->
      Bizdays.preceding(Bizdays.anbima(), ~D[2001-01-01])
    end
  end

  test "terminates when all weekdays or all dates are unavailable" do
    for options <- [
          [weekend: Enum.to_list(1..7)],
          [weekend: [], holidays: Enum.to_list(Date.range(~D[2026-02-13], ~D[2026-02-18]))]
        ] do
      calendar =
        Calendar.new(options ++ [first_date: ~D[2026-02-13], last_date: ~D[2026-02-18]])

      refute Bizdays.business_day?(calendar, ~D[2026-02-16])

      for operation <- [&Bizdays.following/2, &Bizdays.preceding/2] do
        assert_raise ArgumentError, ~r/no business day.*boundary/, fn ->
          operation.(calendar, ~D[2026-02-16])
        end
      end
    end
  end

  test "rejects non-ISO, invalid and out-of-bounds dates in all operations" do
    calendar = Calendar.new(first_date: ~D[2026-01-01], last_date: ~D[2026-12-31])

    for date <- [
          ~D[2000-12-31],
          ~D[2100-01-01],
          ~D[2025-12-31],
          ~D[2027-01-01],
          ~N[2026-02-16 00:00:00],
          ~U[2026-02-16 00:00:00Z],
          "2026-02-16",
          nil,
          %Date{year: 2026, month: 2, day: 30},
          %Date{year: 2026, month: 1, day: 1, calendar: __MODULE__}
        ],
        operation <- [&Bizdays.business_day?/2, &Bizdays.following/2, &Bizdays.preceding/2] do
      assert_raise ArgumentError, fn -> operation.(calendar, date) end
    end
  end

  test "adjustments are nearest business days and idempotent across a sample year" do
    calendar = Bizdays.anbima()

    for date <- Date.range(~D[2026-01-01], ~D[2026-12-31]) do
      following = Bizdays.following(calendar, date)
      preceding = Bizdays.preceding(calendar, date)

      assert Bizdays.business_day?(calendar, following)
      assert Bizdays.business_day?(calendar, preceding)
      assert Date.compare(following, date) != :lt
      assert Date.compare(preceding, date) != :gt
      assert Bizdays.following(calendar, following) == following
      assert Bizdays.preceding(calendar, preceding) == preceding

      for skipped <- Date.range(date, following), skipped != following do
        refute Bizdays.business_day?(calendar, skipped)
      end

      for skipped <- Date.range(preceding, date), skipped != preceding do
        refute Bizdays.business_day?(calendar, skipped)
      end
    end
  end
end
