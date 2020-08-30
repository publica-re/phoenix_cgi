#/usr/bin/env elixir

defmodule Main do
  def encode(map) do
    IO.puts "{"
    for {k, v} <- map do
      IO.puts "\"#{k}\": \"#{v}\""
    end
    IO.puts "}"
  end

  def run do
    IO.puts "Content-Type: application/json"
    IO.puts ""

    encode(System.get_env())
  end
end

Main.run()
