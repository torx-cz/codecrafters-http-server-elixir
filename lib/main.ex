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
    IO.puts("Client connected: #{:inet.peername(client) |> inspect}")
    {:ok, pid} = Task.Supervisor.start_child(Server.TaskSupervisor, fn -> server(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)

    loop_acceptor(socket)
  end

  def server(client) do
    {:ok, data} = :gen_tcp.recv(client, 0)
    [request_line | _] = String.split(data, "\r\n")

    case String.split(request_line, " ", parts: 3) do
      ["GET", "/", _] ->
        :ok = :gen_tcp.send(client, "HTTP/1.1 200 OK\r\n\r\n")

      ["GET", "/echo/" <> str, _] ->
        :ok =
          :gen_tcp.send(
            client,
            "HTTP/1.1 200 OK\r\n" <>
              "Content-Type: text/plain\r\nContent-Length: #{byte_size(str)}\r\n\r\n" <> "#{str}"
          )

      ["GET", _path, _] ->
        :ok = :gen_tcp.send(client, "HTTP/1.1 404 Not Found\r\n\r\n")

      _ ->
        :ok = :gen_tcp.send(client, "HTTP/1.1 404 Not Found\r\n\r\n")
    end

    :ok = :gen_tcp.close(client)
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
