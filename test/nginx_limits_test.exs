defmodule Kapten.Nginx.LimitsTest do
  use ExUnit.Case, async: true

  alias Kapten.Nginx.Limits

  test "no limits is a file that limits nothing" do
    conf = Limits.conf("example.com": [http: 4000])
    refute conf =~ "limit_req"
  end

  test "a limit counts its server's address on its path and methods only" do
    conf =
      Limits.conf(
        "a.example.com": [http: 4000, limits: [[path: "/host", methods: ["POST"], rate: "10r/m", burst: 5]]],
        "b.example.com": [http: 4001, limits: [[path: "/x", rate: "2r/s"]]]
      )

    assert conf =~ "limit_req_status 429;"
    assert conf =~ ~S|"~^a\.example\.com:(POST):/host$" $binary_remote_addr;|
    assert conf =~ "limit_req_zone $kapten_limit_0 zone=kapten_limit_0:1m rate=10r/m;"
    assert conf =~ "limit_req zone=kapten_limit_0 burst=5 nodelay;"
    assert conf =~ ~S|"~^b\.example\.com:[A-Z]+:/x$" $binary_remote_addr;|
    assert conf =~ "limit_req zone=kapten_limit_1 burst=0 nodelay;"
  end

  test "a limit that would not be valid nginx stops the start" do
    for limit <- [
          [path: "host", rate: "1r/s"],
          [path: "/a b", rate: "1r/s"],
          [path: "/a", rate: "1r/h"],
          [path: "/a", rate: "1r/s", burst: -1],
          [path: "/a", rate: "1r/s", methods: ["post"]]
        ] do
      assert_raise ArgumentError, fn -> Limits.conf("a.com": [http: 1, limits: [limit]]) end
    end
  end
end
