defmodule Bizdays do
  @moduledoc """
  Business day calculations for the Brazilian financial market.

  Use `anbima/0` for the built-in 2001–2099 calendar, or `Bizdays.Calendar.new/1`
  for a custom calendar. All calendar operations take the calendar first.

  `count/3` excludes the starting date and includes the ending date; `range/3`
  includes both endpoints when they are business days. `add/3` accepts signed
  integer offsets and adjusts forward when the offset is zero.

  Dates must use `Elixir.Calendar.ISO` and fall within the calendar's inclusive bounds.
  Invalid dates and operations that exceed those bounds raise `ArgumentError`.
  """

  alias Bizdays.ANBIMA
  alias Bizdays.Calendar
  alias Elixir.Calendar.ISO

  @anbima Calendar.new(
            name: "ANBIMA",
            holidays: Enum.flat_map(2001..2099, &ANBIMA.holidays/1)
          )

  @doc """
  Returns the ANBIMA calendar for 2001–2099.

  Holidays are calculated once at compile time. Saturdays and Sundays are
  weekend days, and both date boundaries are inclusive.

  ## Examples

      iex> cal = Bizdays.anbima()
      iex> cal.name
      "ANBIMA"
      iex> MapSet.member?(cal.holidays, ~D[2026-02-16])
      true
  """
  @spec anbima() :: Calendar.t()
  def anbima, do: @anbima

  @doc """
  Returns whether an ISO date is a business day in the calendar.

  A business day is neither a configured weekend day nor a holiday.
  Raises `ArgumentError` for invalid dates, non-ISO dates, or dates outside
  the calendar's inclusive boundaries.

  ## Examples

      iex> Bizdays.business_day?(Bizdays.anbima(), ~D[2026-02-16])
      false

      iex> Bizdays.business_day?(Bizdays.anbima(), ~D[2026-02-18])
      true
  """
  @spec business_day?(Calendar.t(), Date.t()) :: boolean()
  def business_day?(%Calendar{} = calendar, date) do
    validate_date!(calendar, date)
    business_day_unchecked?(calendar, date)
  end

  @doc """
  Returns the first business day on or after `date`.

  A business day is returned unchanged. Raises `ArgumentError` for invalid
  or out-of-bounds dates, or if no business day exists on or after the date
  within the calendar boundaries.

  ## Examples

      iex> Bizdays.following(Bizdays.anbima(), ~D[2026-02-16])
      ~D[2026-02-18]
  """
  @spec following(Calendar.t(), Date.t()) :: Date.t()
  def following(%Calendar{} = calendar, date) do
    validate_date!(calendar, date)
    seek_business_day(calendar, date, 1, calendar.last_date)
  end

  @doc """
  Returns the last business day on or before `date`.

  A business day is returned unchanged. Raises `ArgumentError` for invalid
  or out-of-bounds dates, or if no business day exists on or before the date
  within the calendar boundaries.

  ## Examples

      iex> Bizdays.preceding(Bizdays.anbima(), ~D[2026-02-16])
      ~D[2026-02-13]
  """
  @spec preceding(Calendar.t(), Date.t()) :: Date.t()
  def preceding(%Calendar{} = calendar, date) do
    validate_date!(calendar, date)
    seek_business_day(calendar, date, -1, calendar.first_date)
  end

  @doc """
  Moves `date` by an integer number of business days.

  Positive values count business days strictly after the starting date;
  negative values count strictly before it, even when the start is not a
  business day. Zero returns `following(calendar, date)`.

  Unlike python-bizdays `offset(date, 0)`, zero adjusts a non-business date.
  Raises `ArgumentError` for invalid dates, non-integer offsets, or when
  the input or result would fall outside the calendar boundaries.

  ## Examples

      iex> Bizdays.add(Bizdays.anbima(), ~D[2026-02-13], 1)
      ~D[2026-02-18]

      iex> Bizdays.add(Bizdays.anbima(), ~D[2026-02-16], -1)
      ~D[2026-02-13]

      iex> Bizdays.add(Bizdays.anbima(), ~D[2026-02-16], 0)
      ~D[2026-02-18]
  """
  @spec add(Calendar.t(), Date.t(), integer()) :: Date.t()
  def add(%Calendar{} = calendar, date, n) when is_integer(n) do
    validate_date!(calendar, date)

    cond do
      n == 0 -> seek_business_day(calendar, date, 1, calendar.last_date)
      n > 0 -> add_business_days(calendar, date, n, 1, calendar.last_date)
      n < 0 -> add_business_days(calendar, date, -n, -1, calendar.first_date)
    end
  end

  def add(%Calendar{}, _date, n) do
    raise ArgumentError, "expected an integer business day offset, got: #{inspect(n)}"
  end

  @doc """
  Counts business days in `(from, to]`: excludes the start and includes the end.

  Equal dates return zero, including holidays. For reversed dates, returns
  `-count(calendar, to, from)`. Endpoints are never adjusted to business days.
  This explicit convention can differ from python-bizdays when endpoints
  are not business days.

  Raises `ArgumentError` for invalid or out-of-bounds dates, including when
  both endpoints are equal.

  ## Examples

      iex> Bizdays.count(Bizdays.anbima(), ~D[2012-12-31], ~D[2013-01-03])
      2

      iex> Bizdays.count(Bizdays.anbima(), ~D[2013-01-03], ~D[2012-12-31])
      -2

      iex> Bizdays.count(Bizdays.anbima(), ~D[2026-02-16], ~D[2026-02-18])
      1
  """
  @spec count(Calendar.t(), Date.t(), Date.t()) :: integer()
  def count(%Calendar{} = calendar, from, to) do
    validate_date!(calendar, from)
    validate_date!(calendar, to)

    case Date.compare(from, to) do
      :eq -> 0
      :lt -> count_forward(calendar, from, to)
      :gt -> -count_forward(calendar, to, from)
    end
  end

  @doc """
  Applies `following/2`, switching to `preceding/2` if the result changes month.

  Business dates remain unchanged. Each search must succeed within the
  calendar boundaries; an out-of-bounds search raises `ArgumentError`
  rather than triggering the opposite adjustment. The fallback can itself
  leave the original month if that month has no business days.

  ## Examples

      iex> Bizdays.modified_following(Bizdays.anbima(), ~D[2026-01-31])
      ~D[2026-01-30]
  """
  @spec modified_following(Calendar.t(), Date.t()) :: Date.t()
  def modified_following(%Calendar{} = calendar, date) do
    adjusted = following(calendar, date)

    if {adjusted.year, adjusted.month} == {date.year, date.month} do
      adjusted
    else
      preceding(calendar, date)
    end
  end

  @doc """
  Applies `preceding/2`, switching to `following/2` if the result changes month.

  Business dates remain unchanged. Each search must succeed within the
  calendar boundaries; an out-of-bounds search raises `ArgumentError`
  rather than triggering the opposite adjustment. The fallback can itself
  leave the original month if that month has no business days.

  ## Examples

      iex> Bizdays.modified_preceding(Bizdays.anbima(), ~D[2026-03-01])
      ~D[2026-03-02]
  """
  @spec modified_preceding(Calendar.t(), Date.t()) :: Date.t()
  def modified_preceding(%Calendar{} = calendar, date) do
    adjusted = preceding(calendar, date)

    if {adjusted.year, adjusted.month} == {date.year, date.month} do
      adjusted
    else
      following(calendar, date)
    end
  end

  @doc """
  Lists business days from `from` to `to`, including both endpoints if they are business days.

  The result follows the input direction: reversed endpoints produce a
  descending list. Equal endpoints return a singleton for a business day,
  or an empty list otherwise. Unlike `count/3`, the start is included.

  Raises `ArgumentError` for invalid or out-of-bounds dates.

  ## Examples

      iex> Bizdays.range(Bizdays.anbima(), ~D[2026-02-13], ~D[2026-02-19])
      [~D[2026-02-13], ~D[2026-02-18], ~D[2026-02-19]]

      iex> Bizdays.range(Bizdays.anbima(), ~D[2026-02-19], ~D[2026-02-13])
      [~D[2026-02-19], ~D[2026-02-18], ~D[2026-02-13]]
  """
  @spec range(Calendar.t(), Date.t(), Date.t()) :: [Date.t()]
  def range(%Calendar{} = calendar, from, to) do
    validate_date!(calendar, from)
    validate_date!(calendar, to)
    step = if Date.compare(from, to) == :gt, do: -1, else: 1

    from
    |> Date.range(to, step)
    |> Enum.filter(&business_day_unchecked?(calendar, &1))
  end

  @doc """
  Lists the calendar's holidays in `year`, in chronological order.

  Includes holidays on weekends, but does not add ordinary weekend days.
  For a calendar covering only part of a year, returns holidays within its
  available boundaries. An empty year returns `[]`.

  Raises `ArgumentError` unless the year is an integer overlapping the
  calendar's supported interval.

  ## Examples

      iex> Bizdays.holidays(Bizdays.anbima(), 2026) |> Enum.take(3)
      [~D[2026-01-01], ~D[2026-02-16], ~D[2026-02-17]]

      iex> Bizdays.holidays(Bizdays.Calendar.new(), 2026)
      []
  """
  @spec holidays(Calendar.t(), integer()) :: [Date.t()]
  def holidays(%Calendar{} = calendar, year) when is_integer(year) do
    if year < calendar.first_date.year or year > calendar.last_date.year do
      raise ArgumentError, "year #{year} is outside the calendar boundaries"
    end

    calendar.holidays
    |> Enum.filter(&(&1.year == year))
    |> Enum.sort(Date)
  end

  def holidays(%Calendar{}, year) do
    raise ArgumentError, "expected an integer year, got: #{inspect(year)}"
  end

  defp count_forward(calendar, from, to) do
    days = Date.diff(to, from)
    full_weeks = div(days, 7) * (7 - length(calendar.weekend))
    remainder = rem(days, 7)
    start_weekday = Date.day_of_week(from)

    remaining_weekdays =
      Enum.count(1..6, fn offset ->
        offset <= remainder and (rem(start_weekday + offset - 1, 7) + 1) not in calendar.weekend
      end)

    holidays =
      Enum.count(calendar.holidays, fn date ->
        Date.compare(date, from) == :gt and Date.compare(date, to) != :gt and
          Date.day_of_week(date) not in calendar.weekend
      end)

    full_weeks + remaining_weekdays - holidays
  end

  defp add_business_days(_calendar, date, 0, _step, _boundary), do: date

  defp add_business_days(calendar, date, remaining, step, boundary) do
    if date == boundary do
      raise ArgumentError, "business day offset exceeds calendar boundary #{boundary}"
    end

    next = seek_business_day(calendar, Date.add(date, step), step, boundary)
    add_business_days(calendar, next, remaining - 1, step, boundary)
  end

  defp business_day_unchecked?(calendar, date) do
    Date.day_of_week(date) not in calendar.weekend and
      not MapSet.member?(calendar.holidays, date)
  end

  defp seek_business_day(calendar, date, step, boundary) do
    cond do
      business_day_unchecked?(calendar, date) ->
        date

      date == boundary ->
        raise ArgumentError, "no business day found before reaching calendar boundary #{boundary}"

      true ->
        seek_business_day(calendar, Date.add(date, step), step, boundary)
    end
  end

  defp validate_date!(calendar, %Date{calendar: ISO, year: year, month: month, day: day} = date)
       when is_integer(year) and is_integer(month) and is_integer(day) do
    case Date.new(year, month, day) do
      {:ok, _date} -> :ok
      {:error, _reason} -> raise ArgumentError, "expected a valid ISO Date, got: #{inspect(date)}"
    end

    if Date.compare(date, calendar.first_date) == :lt or
         Date.compare(date, calendar.last_date) == :gt do
      raise ArgumentError,
            "date #{date} is outside calendar boundaries #{calendar.first_date}..#{calendar.last_date}"
    end
  end

  defp validate_date!(_calendar, date) do
    raise ArgumentError, "expected an ISO Date, got: #{inspect(date)}"
  end
end
