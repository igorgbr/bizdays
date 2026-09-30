defmodule Bizdays.Easter do
  @moduledoc """
  Calculates Gregorian Easter Sunday for the supported years, 2001–2099.
  """

  @doc """
  Returns Easter Sunday as an ISO date.

  Raises `ArgumentError` unless `year` is an integer between 2001 and 2099.

  ## Examples

      iex> Bizdays.Easter.date(2024)
      ~D[2024-03-31]

      iex> Bizdays.Easter.date(2026)
      ~D[2026-04-05]
  """
  @spec date(integer()) :: Date.t()
  def date(year) when is_integer(year) and year in 2001..2099 do
    # Anonymous Gregorian algorithm (Meeus/Jones/Butcher).
    # Source: Jean Meeus, Astronomical Algorithms, 2nd ed., chapter 8.
    # Letter names follow the published algorithm to simplify comparison.
    a = rem(year, 19)
    b = div(year, 100)
    c = rem(year, 100)
    d = div(b, 4)
    e = rem(b, 4)
    f = div(b + 8, 25)
    g = div(b - f + 1, 3)
    h = rem(19 * a + b - d - g + 15, 30)
    i = div(c, 4)
    k = rem(c, 4)
    l = rem(32 + 2 * e + 2 * i - h - k, 7)
    m = div(a + 11 * h + 22 * l, 451)
    value = h + l - 7 * m + 114

    Date.new!(year, div(value, 31), rem(value, 31) + 1)
  end

  def date(year) do
    raise ArgumentError, "expected an integer year between 2001 and 2099, got: #{inspect(year)}"
  end
end
