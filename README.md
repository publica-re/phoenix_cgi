# PhoenixCGI

A small CGI controller for Phoenix.

---

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
