defmodule PhoenixCGI.CacheRawBody do
  import Plug.Conn

  @moduledoc """
  Caches the content of the request body for later use.
  """

  @doc """
  Reads the body and caches it in a private register
  """
  def read_body(conn, opts \\ []) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        body = [body | read_cached_body(conn) || []]
        conn = put_private(conn, :raw_body, body)
        {:ok, body, conn}
      any -> any
    end
  end

  @doc """
  Reads the cached body
  """
  def read_cached_body(conn) do
    conn.private[:raw_body]
  end
end
