defmodule BizdaysTest do
  use ExUnit.Case, async: true

  alias Bizdays.ANBIMA
  alias Bizdays.Calendar

  doctest Bizdays

  test "returns the complete ANBIMA calendar with inclusive boundaries" do
    calendar = Bizdays.anbima()

    assert %Calendar{} = calendar
    assert calendar.name == "ANBIMA"
    assert calendar.weekend == [6, 7]
    assert calendar.first_date == ~D[2001-01-01]
    assert calendar.last_date == ~D[2099-12-31]

    expected = MapSet.new(Enum.flat_map(2001..2099, &ANBIMA.holidays/1))
    assert calendar.holidays == expected
  end

  test "customizing a calendar leaves the built-in calendar unchanged" do
    original = Bizdays.anbima()
    local_holiday = ~D[2026-01-25]

    custom =
      Calendar.new(
        name: "ANBIMA + local holiday",
        holidays: MapSet.put(original.holidays, local_holiday)
      )

    assert MapSet.member?(custom.holidays, local_holiday)
    refute MapSet.member?(Bizdays.anbima().holidays, local_holiday)
    assert Bizdays.anbima() == original
  end
end
