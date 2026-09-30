defmodule Bizdays.ANBIMA do
  @moduledoc """
  Rule-based ANBIMA holidays for 2001–2099.

  Includes national holidays affecting bank reserves, including holidays on
  weekends. Municipal and state holidays, elections, and the last banking
  day of the year are not added.
  """

  alias Bizdays.Easter

  # ANBIMA's national bank holiday calendar:
  # https://www.anbima.com.br/feriados/feriados.asp
  @fixed_holidays [
    {1, 1},
    {4, 21},
    {5, 1},
    {9, 7},
    {10, 12},
    {11, 2},
    {11, 15},
    {12, 25}
  ]

  # Carnival Monday/Tuesday, Good Friday, and Corpus Christi relative to Easter.
  # Source: ANBIMA calendar above. Its note on CMN Resolution 2,516 confirms
  # that Maundy Thursday is a business day since 2000, so it is not included.
  @easter_offsets [-48, -47, -2, 60]

  @doc """
  Returns the year's holiday dates, unique and in chronological order.

  Weekend holidays stay on their original dates; no substitute day is added.
  November 20 is included starting in 2024.

  Raises `ArgumentError` unless `year` is an integer between 2001 and 2099.

  ## Examples

      iex> Bizdays.ANBIMA.holidays(2026) |> Enum.take(4)
      [~D[2026-01-01], ~D[2026-02-16], ~D[2026-02-17], ~D[2026-04-03]]

      iex> ~D[2023-11-20] in Bizdays.ANBIMA.holidays(2023)
      false

      iex> ~D[2024-11-20] in Bizdays.ANBIMA.holidays(2024)
      true
  """
  @spec holidays(integer()) :: [Date.t()]
  def holidays(year) when is_integer(year) and year in 2001..2099 do
    easter = Easter.date(year)
    fixed = Enum.map(@fixed_holidays, fn {month, day} -> Date.new!(year, month, day) end)
    movable = Enum.map(@easter_offsets, &Date.add(easter, &1))

    # Law 14,759 was published in December 2023; the first November 20 after
    # it took effect is in 2024, matching ANBIMA's calendar.
    # https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2023/lei/l14759.htm
    black_awareness_day = if year >= 2024, do: [Date.new!(year, 11, 20)], else: []

    (fixed ++ movable ++ black_awareness_day)
    |> Enum.uniq()
    |> Enum.sort(Date)
  end

  def holidays(year) do
    raise ArgumentError, "expected an integer year between 2001 and 2099, got: #{inspect(year)}"
  end
end
