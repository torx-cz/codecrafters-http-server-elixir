defmodule Server do
  use Application

  def start(_type, _args) do
    Supervisor.start_link(
      [{Task.Supervisor, name: Server.TaskSupervisor}, {Task, fn -> Server.listen() end}],
      strategy: :one_for_one
    )
  end

  def listen() do
    port = 4221

    # Since the tester restarts your program quite often, setting SO_REUSEADDR
    # ensures that we don't run into 'Address already in use' errors
    {:ok, socket} = :gen_tcp.listen(port, [:binary, active: false, reuseaddr: true])
    IO.puts("Acception connections on port #{port}")
    loop_acceptor(socket)
  end

  def loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    # Spawn own task for handling requests from that client
    IO.puts("[#{inspect(client)}] Client connected: #{:inet.peername(client) |> inspect}")

    {:ok, pid} = Task.Supervisor.start_child(Server.TaskSupervisor, fn -> server(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)

    loop_acceptor(socket)
  end

  def server(client) do
    {:ok, data} = :gen_tcp.recv(client, 0)
    request = HTTPParser.parse(data)
    IO.puts("[#{inspect(client)}] Request received: #{inspect(request)}")

    %{method: method, path: path} = request

    case {method, path} do
      {"GET", "/"} ->
        :ok = :gen_tcp.send(client, "HTTP/1.1 200 OK\r\n\r\n")

      {"GET", "/echo/" <> str} ->
        :ok = :gen_tcp.send(client, generate_http_response_200(str))

      {"GET", "/user-agent"} ->
        case request.headers["user-agent"] do
          # TODO return some HTTP error - missing user-agent
          nil -> :error
          value -> :ok = :gen_tcp.send(client, generate_http_response_200(value))
        end

      _ ->
        :ok = :gen_tcp.send(client, "HTTP/1.1 404 Not Found\r\n\r\n")
    end

    :ok = :gen_tcp.close(client)
  end

  def generate_http_response_200(data) do
    "HTTP/1.1 200 OK\r\n" <>
      "Content-Type: text/plain\r\nContent-Length: #{byte_size(data)}\r\n\r\n" <> "#{data}"
  end
end

defmodule HTTPParser do
  def parse(request) do
    [header_section | body] = String.split(request, "\r\n\r\n", parts: 2)

    [request_line | header_lines] = String.split(header_section, "\r\n")
    [method, path, "HTTP/1.1"] = String.split(request_line, " ", parts: 3)

    headers = parse_headers(header_lines)

    %{method: method, path: path, headers: headers, body: body}
  end

  defp parse_headers(lines) do
    lines
    |> Enum.map(fn line -> String.split(line, ":", parts: 2) end)
    |> Enum.map(fn [key, value] -> {String.downcase(key), String.trim(value)} end)
    |> Enum.into(%{})
  end
end

defmodule CLI do
  def main(_args) do
    # Start the Server application
    {:ok, _pid} = Application.ensure_all_started(:codecrafters_http_server)

    # Run forever
    Process.sleep(:infinity)
  end
end
