defmodule Bizdays.Calendar do
  @moduledoc """
  An immutable business calendar with inclusive date boundaries.

  Build calendars with `new/1` to validate their configuration.
  """

  defstruct name: nil,
            holidays: MapSet.new(),
            weekend: [6, 7],
            first_date: ~D[2001-01-01],
            last_date: ~D[2099-12-31]

  @type t :: %__MODULE__{
          name: String.t() | nil,
          holidays: MapSet.t(Date.t()),
          weekend: [1..7],
          first_date: Date.t(),
          last_date: Date.t()
        }

  @doc """
  Builds a calendar from keyword options.

  ## Options

    * `:name` — a string or `nil` (default).
    * `:holidays` — a list or `MapSet` of ISO dates; defaults to `[]`.
    * `:weekend` — a list of ISO weekday numbers (Monday = 1, Sunday = 7);
      defaults to `[6, 7]`. An empty list means no weekly days off.
    * `:first_date` — inclusive lower bound; defaults to `~D[2001-01-01]`.
    * `:last_date` — inclusive upper bound; defaults to `~D[2099-12-31]`.

  Boundaries must stay within 2001–2099, and every holiday must be within
  those boundaries. Duplicate holidays and weekend days are removed.
  Weekend days are sorted. Raises `ArgumentError` for invalid options.

  ## Examples

      iex> cal = Bizdays.Calendar.new(name: "Custom", holidays: [~D[2026-01-25]])
      iex> cal.name
      "Custom"
      iex> MapSet.member?(cal.holidays, ~D[2026-01-25])
      true
      iex> cal.weekend
      [6, 7]
  """
  @spec new(keyword()) :: t()
  def new(options \\ []) do
    unless Keyword.keyword?(options) do
      raise ArgumentError, "expected calendar options to be a keyword list"
    end

    options = Keyword.validate!(options, [:name, :holidays, :weekend, :first_date, :last_date])
    calendar = struct!(__MODULE__, options)
    validate_name!(calendar.name)
    validate_bounds!(calendar.first_date, calendar.last_date)

    %{
      calendar
      | holidays: holidays!(calendar.holidays, calendar.first_date, calendar.last_date),
        weekend: weekend!(calendar.weekend)
    }
  end

  defp validate_name!(name) when is_binary(name) or is_nil(name), do: :ok

  defp validate_name!(_name) do
    raise ArgumentError, "expected name to be a string or nil"
  end

  defp validate_bounds!(first_date, last_date) do
    validate_date!(first_date)
    validate_date!(last_date)

    if Date.compare(first_date, last_date) == :gt do
      raise ArgumentError, "expected first_date to be on or before last_date"
    end
  end

  defp validate_date!(%Date{calendar: Calendar.ISO, year: year} = date)
       when year in 2001..2099 do
    case Date.new(year, date.month, date.day) do
      {:ok, _date} -> :ok
      {:error, _reason} -> raise ArgumentError, "expected a valid ISO date, got: #{inspect(date)}"
    end
  end

  defp validate_date!(date) do
    raise ArgumentError, "expected an ISO Date within 2001–2099, got: #{inspect(date)}"
  end

  defp holidays!(holidays, first_date, last_date)
       when is_list(holidays) or is_struct(holidays, MapSet) do
    Enum.each(holidays, fn date ->
      validate_date!(date)

      if Date.compare(date, first_date) == :lt or Date.compare(date, last_date) == :gt do
        raise ArgumentError, "holiday #{date} is outside the calendar boundaries"
      end
    end)

    MapSet.new(holidays)
  end

  defp holidays!(_holidays, _first_date, _last_date) do
    raise ArgumentError, "expected holidays to be a list or MapSet of ISO dates"
  end

  defp weekend!(days) when is_list(days) do
    unless Enum.all?(days, &(is_integer(&1) and &1 in 1..7)) do
      raise ArgumentError, "expected weekend to contain weekday integers from 1 to 7"
    end

    days |> Enum.uniq() |> Enum.sort()
  end

  defp weekend!(_days) do
    raise ArgumentError, "expected weekend to be a list of weekday integers from 1 to 7"
  end
end
