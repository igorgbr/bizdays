defmodule Bizdays.ANBIMAFixtureTest do
  use ExUnit.Case, async: true

  alias Bizdays.ANBIMA

  @fixture Path.expand("../fixtures/anbima_feriados.csv", __DIR__)

  test "matches the complete official ANBIMA holiday fixture for 2001–2099" do
    official =
      @fixture
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&Date.from_iso8601!/1)

    # Snapshot integrity: 1,264 spreadsheet rows, with 2079-04-21 listed twice.
    # Provenance and conversion instructions: test/fixtures/README.md.
    assert length(official) == 1263
    assert official == Enum.sort(Enum.uniq(official), Date)
    assert Enum.uniq(Enum.map(official, & &1.year)) == Enum.to_list(2001..2099)

    for year <- 2001..2099 do
      expected = Enum.filter(official, &(&1.year == year))
      actual = ANBIMA.holidays(year)

      assert actual == expected,
             "ANBIMA mismatch in #{year}: " <>
               "missing #{inspect(expected -- actual)}, extra #{inspect(actual -- expected)}"
    end

    assert Bizdays.anbima().holidays == MapSet.new(official)
  end
end
