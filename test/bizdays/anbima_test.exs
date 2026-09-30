defmodule Bizdays.ANBIMATest do
  use ExUnit.Case, async: true

  alias Bizdays.ANBIMA

  doctest ANBIMA

  # Expected dates transcribed from ANBIMA's official annual pages.
  test "matches the 2023 calendar, before November 20 became a national holiday" do
    # https://www.anbima.com.br/feriados/fer_nacionais/2023.asp
    assert ANBIMA.holidays(2023) == [
             ~D[2023-01-01],
             ~D[2023-02-20],
             ~D[2023-02-21],
             ~D[2023-04-07],
             ~D[2023-04-21],
             ~D[2023-05-01],
             ~D[2023-06-08],
             ~D[2023-09-07],
             ~D[2023-10-12],
             ~D[2023-11-02],
             ~D[2023-11-15],
             ~D[2023-12-25]
           ]
  end

  test "matches the 2024 calendar, including November 20" do
    # https://www.anbima.com.br/feriados/fer_nacionais/2024.asp
    assert ANBIMA.holidays(2024) == [
             ~D[2024-01-01],
             ~D[2024-02-12],
             ~D[2024-02-13],
             ~D[2024-03-29],
             ~D[2024-04-21],
             ~D[2024-05-01],
             ~D[2024-05-30],
             ~D[2024-09-07],
             ~D[2024-10-12],
             ~D[2024-11-02],
             ~D[2024-11-15],
             ~D[2024-11-20],
             ~D[2024-12-25]
           ]
  end

  test "matches the 2026 calendar" do
    # https://www.anbima.com.br/feriados/fer_nacionais/2026.asp
    assert ANBIMA.holidays(2026) == [
             ~D[2026-01-01],
             ~D[2026-02-16],
             ~D[2026-02-17],
             ~D[2026-04-03],
             ~D[2026-04-21],
             ~D[2026-05-01],
             ~D[2026-06-04],
             ~D[2026-09-07],
             ~D[2026-10-12],
             ~D[2026-11-02],
             ~D[2026-11-15],
             ~D[2026-11-20],
             ~D[2026-12-25]
           ]
  end

  test "keeps weekend holidays without adding substitute days" do
    holidays = ANBIMA.holidays(2023)

    assert ~D[2023-01-01] in holidays
    refute ~D[2023-01-02] in holidays
  end

  test "excludes Maundy Thursday, Ash Wednesday, local holidays and year-end closures" do
    holidays = ANBIMA.holidays(2024)

    for date <- [~D[2024-03-28], ~D[2024-02-14], ~D[2024-01-25], ~D[2024-12-31]] do
      refute date in holidays
    end
  end

  test "returns unique ISO dates in chronological order throughout the supported interval" do
    for year <- 2001..2099 do
      holidays = ANBIMA.holidays(year)

      assert holidays == Enum.sort(holidays, Date)
      assert length(holidays) == MapSet.size(MapSet.new(holidays))
      assert Enum.all?(holidays, &(&1.year == year and &1.calendar == Calendar.ISO))
      assert Date.new!(year, 1, 1) in holidays
      assert Date.new!(year, 12, 25) in holidays
      assert Date.new!(year, 11, 20) in holidays == year >= 2024
    end
  end

  test "rejects unsupported years and invalid input types" do
    for year <- [2000, 2100, -1, 2024.0, "2024", nil, ~D[2024-01-01]] do
      assert_raise ArgumentError, ~r/expected an integer year between 2001 and 2099/, fn ->
        ANBIMA.holidays(year)
      end
    end
  end
end
