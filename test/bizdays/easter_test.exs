defmodule Bizdays.EasterTest do
  use ExUnit.Case, async: true

  alias Bizdays.Easter

  doctest Easter

  test "returns known Easter dates" do
    for {year, expected} <- [
          {2001, ~D[2001-04-15]},
          {2024, ~D[2024-03-31]},
          {2025, ~D[2025-04-20]},
          {2026, ~D[2026-04-05]},
          {2099, ~D[2099-04-12]}
        ] do
      assert Easter.date(year) == expected
    end
  end

  test "handles the late-April correction cases" do
    assert Easter.date(2049) == ~D[2049-04-18]
    assert Easter.date(2076) == ~D[2076-04-19]
  end

  test "always returns a Sunday within the Gregorian Easter window" do
    # Ecclesiastical bounds: https://aa.usno.navy.mil/faq/easter
    for year <- 2001..2099 do
      date = Easter.date(year)

      assert date.calendar == Calendar.ISO
      assert date.year == year
      assert Date.day_of_week(date) == 7
      assert Date.compare(date, Date.new!(year, 3, 22)) != :lt
      assert Date.compare(date, Date.new!(year, 4, 25)) != :gt
    end
  end

  test "rejects unsupported years and invalid input types" do
    for year <- [2000, 2100, -1, 2024.0, "2024", nil, ~D[2024-03-31]] do
      assert_raise ArgumentError, ~r/expected an integer year between 2001 and 2099/, fn ->
        Easter.date(year)
      end
    end
  end
end
