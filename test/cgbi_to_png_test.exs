defmodule CgbiToPngTest do
  use ExUnit.Case

  test "Normal CgBI Png" do
    CgbiToPng.to_png("test/icon_180.png")
    |> IO.inspect
  end

  test "PNG8" do
    CgbiToPng.to_png("test/icon_180_png8.png")
    |> IO.inspect
  end
end
