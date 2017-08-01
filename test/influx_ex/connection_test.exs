defmodule InfluxEx.ConnectionTest do
  use ExUnit.Case, async: false
  doctest InfluxEx.Connection

  @db_name "influx_ex_test_db"

  setup do
    TestConnection.drop_db(@db_name)
    :ok
  end

  test "create_db" do
    assert :ok == TestConnection.create_db(@db_name)
  end

  test "drop_db" do
    :ok = TestConnection.create_db(@db_name)

    assert :ok == TestConnection.drop_db(@db_name)
  end

  test "write" do
    minimal_point = %{measurement: "cpu",
                      fields: %{load: 0.12}}

    {:error, _} = TestConnection.write(minimal_point, @db_name)


    TestConnection.create_db(@db_name)

    :ok = TestConnection.write(minimal_point, @db_name)
    [{:ok, [result]}] = TestConnection.read("SELECT * FROM cpu", @db_name)
    assert result[:series] == "cpu"
    [%{"load" => 0.12}] = result[:points]

    :ok = TestConnection.write(%{measurement: "series_2",
                                 fields: %{load: 0.12},
                                 tags: %{host: "web-staging"}},
                               @db_name)
    [{:ok, [result]}] = TestConnection.read("SELECT * FROM series_2", @db_name)
    [%{"host" => "web-staging"}] = result[:points]


    :ok = TestConnection.write(%{measurement: "series_3",
                                 fields: %{load: 0.12},
                                 time: 12345678},
                               @db_name)
    [{:ok, [result]}] = TestConnection.read("SELECT * FROM series_3", @db_name)
    [%{"time" => "1970-01-01T00:00:00.012345678Z"}] = result[:points]


    points = for i <- 1..2 do
      %{measurement: "series_4",
        fields: %{load: i + 0.12},
        time: i + 12345670}
    end
    :ok = TestConnection.write(points, @db_name)
    [{:ok, [result]}] = TestConnection.read("SELECT * FROM series_4", @db_name)
    assert length(result[:points]) == 2
  end

  test "query syntax error" do
    assert {:error, _} = TestConnection.read("SELECT * FROM LIMIT", @db_name)
    assert {:error, _} = TestConnection.read("SELECT * FROM LIMIT; SELECT * WHERE", @db_name)
  end

  test "read" do
    [{:error, _}] = TestConnection.read("SELECT * FROM cpu", @db_name)

    TestConnection.create_db(@db_name)
    [{:ok, []}] = TestConnection.read("SELECT * FROM cpu", @db_name)

    for i <- 0..9 do
      :ok = TestConnection.write(%{measurement: "cpu", fields: %{load: i + 0.12}, tags: %{host: "web-staging"}, time: i + 12345678}, @db_name)
    end


    [{:ok, results}] = TestConnection.read("SELECT * FROM cpu", @db_name)

    [series_result] = results
    assert series_result.series == "cpu"
    assert length(series_result.points) == 10
    assert hd(series_result.points) == %{"time" => "1970-01-01T00:00:00.012345678Z",
                                         "load" => 0.12,
                                         "host" => "web-staging"}
  end
end
