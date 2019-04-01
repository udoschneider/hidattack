defmodule HostTestTest do
  use ExUnit.Case
  doctest HostTest

  test "greets the world" do
    assert HostTest.hello() == :world
  end
end
