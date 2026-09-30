defmodule Bizdays.CalendarTest do
  use ExUnit.Case, async: true

  alias Bizdays.Calendar, as: BusinessCalendar

  doctest BusinessCalendar

  test "defaults to an empty calendar with Saturday and Sunday weekends" do
    calendar = BusinessCalendar.new()

    assert calendar.name == nil
    assert calendar.holidays == MapSet.new()
    assert calendar.weekend == [6, 7]
    assert calendar.first_date == ~D[2001-01-01]
    assert calendar.last_date == ~D[2099-12-31]
  end

  test "normalizes holidays and weekend days within inclusive custom boundaries" do
    calendar =
      BusinessCalendar.new(
        name: "Custom",
        holidays: [~D[2026-12-31], ~D[2026-01-01], ~D[2026-01-01]],
        weekend: [7, 5, 7],
        first_date: ~D[2026-01-01],
        last_date: ~D[2026-12-31]
      )

    assert calendar.name == "Custom"
    assert calendar.holidays == MapSet.new([~D[2026-01-01], ~D[2026-12-31]])
    assert calendar.weekend == [5, 7]
    assert calendar.first_date == ~D[2026-01-01]
    assert calendar.last_date == ~D[2026-12-31]
  end

  test "accepts a MapSet, no weekends, and a single-day calendar" do
    calendar =
      BusinessCalendar.new(
        holidays: MapSet.new([~D[2026-01-01]]),
        weekend: [],
        first_date: ~D[2026-01-01],
        last_date: ~D[2026-01-01]
      )

    assert calendar.holidays == MapSet.new([~D[2026-01-01]])
    assert calendar.weekend == []
    assert calendar.first_date == calendar.last_date
  end

  test "rejects invalid options and field types" do
    for options <- [
          nil,
          %{},
          [:holidays],
          [unknown: true],
          [name: :custom],
          [holidays: nil],
          [holidays: %{}],
          [weekend: MapSet.new([6, 7])],
          [weekend: [0]],
          [weekend: [8]],
          [weekend: [6.0]],
          [weekend: ["Sunday"]]
        ] do
      assert_raise ArgumentError, fn -> BusinessCalendar.new(options) end
    end
  end

  test "rejects invalid, non-ISO and unsupported dates in all date fields" do
    for date <- [
          ~D[2000-12-31],
          ~D[2100-01-01],
          ~N[2026-01-01 00:00:00],
          ~U[2026-01-01 00:00:00Z],
          "2026-01-01",
          nil,
          %Date{year: 2026, month: 2, day: 30},
          %Date{year: 2026, month: 1, day: 1, calendar: __MODULE__}
        ],
        options <- [[holidays: [date]], [first_date: date], [last_date: date]] do
      assert_raise ArgumentError, fn -> BusinessCalendar.new(options) end
    end
  end

  test "rejects reversed boundaries and holidays outside custom boundaries" do
    assert_raise ArgumentError, ~r/first_date.*last_date/, fn ->
      BusinessCalendar.new(first_date: ~D[2026-12-31], last_date: ~D[2026-01-01])
    end

    for date <- [~D[2025-12-31], ~D[2027-01-01]] do
      assert_raise ArgumentError, ~r/outside the calendar boundaries/, fn ->
        BusinessCalendar.new(
          holidays: [date],
          first_date: ~D[2026-01-01],
          last_date: ~D[2026-12-31]
        )
      end
    end
  end
end
