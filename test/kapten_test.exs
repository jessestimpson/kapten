defmodule KaptenTest do
  use ExUnit.Case
  doctest Kapten

  test "greets the world" do
    assert Kapten.hello() == :world
  end
end
