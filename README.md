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

## Documentation

The documentation is available on [hexdocs](https://hexdocs.pm/phoenix_cgi/0.1.0/PhoenixCGI.html#content).

## Licence

Copyright (C) 2020 David Baumgartner

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option)
any later version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
more details.

You should have received a copy of the GNU General Public License along
with this program. If not, see <http://www.gnu.org/licenses/>.

## Contribution

I happily accept pull requests through [GitHub](https://github.com/publica-re/phoenix_cgi).
