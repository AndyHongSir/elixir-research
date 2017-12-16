defmodule WtTest do
  use ExUnit.Case
  doctest Wt

  test "greets the world" do
    assert Wt.hello() == :world
  end
end
