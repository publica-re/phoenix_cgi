defmodule PhoenixCGI do
  import Plug.Conn
  require PhoenixCGI.CacheRawBody
  require Logger

  @app Atom.to_string(Mix.Project.config()[:app])
  @version Mix.Project.config()[:version]

  @moduledoc """
  PhoenixCGI allows usage of small CGI scripts as Phoenix plug.

  ## Setup

  Add `PhoenixCGI` to your `deps` in `mix.exs`:

  ```elixir
  defp deps do
    [
      {:phoenix_cgi, "~> 0.1"},
      ...
    ]
  end
  ```

  then, and that's really important, in your `endpoint.ex`, add the following `body_reader` in your `plug Plug.Parsers`:

  ```elixir
  plug Plug.Parsers,
    body_reader: {PhoenixCGI.CacheRawBody, :read_body, []},
    ...
  ```

  This will cause the body of your request to be saved in a private field, so that we will be able to
  pass it to the CGI scripts.

  ## Usage

  You will then be able to use `PhoenixCGI` as any controller. For instance, if you want to serve `git-http-backend` on a
  `/git/` to serve all repositories in `/opt/git/repos/`, you can setup as follows:

  ```elixir
  match :*, "/git/*path", PhoenixCGI,
    binary: "/usr/lib/git-core/git-http-backend",
    extra_env: %{
      GIT_PROJECT_ROOT: "/opt/git/repos/",
      GIT_HTTP_EXPORT_ALL: "1"
    }
  ```

  You can also define a plug that will define, for instance, which project to serve, with `assign/3`.

  ```elixir
  defp set_repo(conn) do
    assign(conn, :extra_env, %{
      GIT_PROJECT_ROOT: "/opt/git/repos/demo.git",
      GIT_HTTP_EXPORT_ALL: "1"
    })
  end
  ```

  and then use it

  ```elixir
  pipeline :git do
    plug :set_repo
  end

  scope "/" do
    pipe_through :git

    match :*, "/git/*path", PhoenixCGI,
      binary: "/usr/lib/git-core/git-http-backend"
  end
  ```



  """

  @doc """
  Prepares the parameters
  """
  def init(default), do: default

  @doc """
  Serves the CGI script given by `:binary`. The following paramters are available:

  | Field name  | Description                                                                                                                                                                                       | Type                                               | Default            |
  |-------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------|--------------------|
  | `binary`    | The binary to use as CGI script                                                                                                                                                                   | string                                             | **required**       |
  | `args`      | The arguments to pass to the script                                                                                                                                                               | list of string                                     | `[]`               |
  | `dir`       | The path to execute the script in                                                                                                                                                                 | string                                             | `File.cwd!()`      |
  | `extra_env` | Supplementary environment variables                                                                                                                                                               | map                                                | `%{}`              |
  | `path_info` | `PATH_INFO` supplied to the script. Can be `{:set, path}` for a fixed path, `{:assign, key}` if it is `assign/3`ed by a plug, or `{:param, name}` for a value that is set in the path parameters. | `{:set, path}`, `{:assign, key}` or `{:param, name}` | `{:param, "path"}` |
  | `timeout`   | After how long should the script be stopped                                                                                                                                                       | integer or `:infinity`                             | `:infinity`        |

  these can either be set when calling the controller or
  in a `plug`, with `assign/3`, with exactly the same
  constraints.
  """
  def call(conn, params) do
    binary = call_retrive_option(conn, params, :binary)
    args = call_retrive_option(conn, params, :args, [])
    extra_env = call_retrive_option(conn, params, :extra_env, %{})
    dir = call_retrive_option(conn, params, :dir, File.cwd!())
    timeout = call_retrive_option(conn, params, :timeout, :infinity)
    path_info = call_retrive_option(conn, params, :path_info, {:param, "path"})

    env = req_prepare_env(conn, binary, path_info)
    body = req_prepare_body(conn)

    out =
      cmd_run(
        binary,
        Map.merge(env, extra_env),
        body,
        dir,
        args,
        timeout
      )

    with {:ok, %Porcelain.Result{err: _stderr, out: stdout, status: 0}} <- out do
      resp_handle_success(conn, stdout |> cmd_normalize_stdout)
    else
      _ -> resp_handle_error(conn, out)
    end
  end

  defp call_retrive_option(conn, params, name, default \\ nil) do
    params[name] || conn.assigns[name] || default
  end

  defp req_retrieve_path_info!(conn, path_info) do
    case path_info do
      {:set, path} -> path
      {:param, param} -> if conn.path_params[param] !== [] and conn.path_params[param] !== nil do
        Path.join("/", Path.join(conn.path_params[param]))
      else
        "/"
      end
      {:assign, name} -> conn.assigns[name]
    end
  end

  defp req_retrieve_ip_address!(%{remote_ip: {a, b, c, d}}), do: "#{a}.#{b}.#{c}.#{d}"

  defp req_retrieve_header!(conn, key), do: List.first(Plug.Conn.get_req_header(conn, key)) || ""

  defp req_prepare_env(conn, script_name, path_info) do
    %{
      SERVER_SOFTWARE: @app <> "/" <> @version,
      SERVER_NAME: conn.host,
      GATEWAY_INTERFACE: "CGI/1.1",
      SERVER_PROTOCOL: "HTTP/1.0",
      SERVER_PORT: Integer.to_string(conn.port),
      REQUEST_METHOD: conn.method,
      PATH_INFO: req_retrieve_path_info!(conn, path_info),
      SCRIPT_NAME: script_name,
      QUERY_STRING: conn.query_string,
      REMOTE_ADDR: req_retrieve_ip_address!(conn),
      CONTENT_TYPE: req_retrieve_header!(conn, "content-type"),
      CONTENT_LENGTH: req_retrieve_header!(conn, "content-length"),
      HTTP_ACCEPT: req_retrieve_header!(conn, "accept"),
      HTTP_ACCEPT_LANGUAGE: req_retrieve_header!(conn, "accept-language"),
      HTTP_USER_AGENT: req_retrieve_header!(conn, "user-agent"),
      HTTP_COOKIE: req_retrieve_header!(conn, "cookie")
    }
  end

  defp req_prepare_body(conn) do
    {:ok, raw_body, _} = PhoenixCGI.CacheRawBody.read_body(conn)
    raw_body
  end

  defp cmd_normalize_stdout([part | rest]),
    do: cmd_normalize_stdout(part) <> cmd_normalize_stdout(rest)

  defp cmd_normalize_stdout([]), do: ""

  defp cmd_normalize_stdout(resp), do: resp

  defp cmd_run(binary, env, body, dir, args, timeout) do
    Logger.debug("Calling CGI script #{binary} with args #{inspect(args)}")
    Logger.info("and env=#{inspect(env)}")

    process =
      Porcelain.spawn(binary, args,
        env: env,
        dir: dir,
        in: :receive,
        out: :iodata,
        err: :iodata
      )

    Porcelain.Process.send_input(process, body)
    Porcelain.Process.await(process, timeout)
  end

  defp resp_handle_success(conn, resp) do
    {headers, body} = resp_chunk!(resp)
    updated_conn = resp_apply_headers!(conn, headers)

    case Map.get(Enum.into(headers, %{}), "status") do
      nil -> resp(updated_conn, 200, body)
      value -> resp(updated_conn, resp_parse_status!(value), body)
    end
  end

  defp resp_chunk!(resp) do
    [header_part, body] = String.split(resp, ["\n\n", "\r\r", "\r\n\r\n"], parts: 2)
    header_lines = String.split(header_part, ["\n", "\r", "\r\n"])
    headers = Enum.map(header_lines, fn line -> resp_parse_header!(line) end)

    {headers, body}
  end

  defp resp_parse_header!(line) do
    %{"key" => key, "value" => value} = Regex.named_captures(~r{(?<key>.*?):(?<value>.*)}, line)
    {String.downcase(String.trim(key)), String.trim(value)}
  end

  defp resp_parse_status!(value) do
    %{"code" => code} = Regex.named_captures(~r{(?<code>[0-9][0-9][0-9])}, value)
    String.to_integer(code)
  end

  defp resp_apply_headers!(conn, [header | rest]) do
    case header do
      {"status", value} ->
        conn |> put_status(resp_parse_status!(value)) |> resp_apply_headers!(rest)

      {"content-type", value} ->
        conn |> put_resp_content_type(value) |> resp_apply_headers!(rest)

      {key, value} ->
        conn |> put_resp_header(key, value) |> resp_apply_headers!(rest)
    end
  end

  defp resp_apply_headers!(conn, []), do: conn

  defp resp_handle_error(
         conn,
         {:ok, %Porcelain.Result{err: err, out: out, status: status}} = args
       ) do
    Logger.info("command failed with status #{inspect(status)}")
    Logger.debug("complete output was #{inspect(args)}")

    resp_handle_error(
      conn,
      "return code #{status}<br />error: <pre>#{inspect(err)}</pre><br />output: <pre>#{
        inspect(out)
      }</pre>"
    )
  end

  defp resp_handle_error(conn, {:error, err}) do
    Logger.error("shell failed with error #{inspect(err)}")

    resp_handle_error(conn, "#{Atom.to_string(err)} - have you set mode +x to your script?")
  end

  defp resp_handle_error(conn, str) when is_bitstring(str) do
    conn
    |> put_resp_content_type("text/html")
    |> resp(500, resp_make_error_page(str))
  end

  defp resp_make_error_page(str) do
    if Mix.env() != :prod do
      "<!doctype html>
<html>
  <head>
    <title>Internal Server Error</title>
    <style type='text/css'>
    pre {
      white-space: pre-wrap;
    }
    </style>
  </head>
  <body>
    <h1>Internal Server Error</h1>
    #{str}
    <p>That's all we know <em>#{@app}/#{@version}</em>.</p>
  </body>
</html>"
    else
      "<!doctype html>
<html>
  <head>
    <title>Internal Server Error</title>
    <style type='text/css'>
    pre {
      white-space: pre-wrap;
    }
    </style>
  </head>
  <body>
    <h1>Internal Server Error</h1>
  </body>
</html>"
    end
  end
end
