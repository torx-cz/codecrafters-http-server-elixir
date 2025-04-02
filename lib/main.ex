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
        :ok = :gen_tcp.send(client, generate_http_response_200(str, "text/plain", request))

      {"GET", "/user-agent"} ->
        case request.headers["user-agent"] do
          # TODO return some HTTP error - missing user-agent
          nil ->
            :error

          value ->
            :ok = :gen_tcp.send(client, generate_http_response_200(value, "text/plain", request))
        end

      {"GET", "/files/" <> filename} ->
        path = Path.join(storage_directory(), filename)

        case File.read(path) do
          {:ok, file_data} ->
            :gen_tcp.send(
              client,
              generate_http_response_200(file_data, "application/octet-stream", request)
            )

          {:error, _} ->
            :gen_tcp.send(client, "HTTP/1.1 404 Not Found\r\n\r\n")
        end

      {"POST", "/files/" <> filename} ->
        with "application/octet-stream" <- request.headers["content-type"],
             {size, ""} <- Integer.parse(request.headers["content-length"]),
             ^size <- byte_size(request.body) do
          path = Path.join(storage_directory(), filename)

          case File.write(path, request.body) do
            :ok -> :gen_tcp.send(client, "HTTP/1.1 201 Created\r\n\r\n")
            {:error, _} -> :error
          end
        end

      _ ->
        :ok = :gen_tcp.send(client, "HTTP/1.1 404 Not Found\r\n\r\n")
    end

    :ok = :gen_tcp.close(client)
  end

  def generate_http_response_200(data, content_type, request) do
    encodings =
      case request.headers["accept-encoding"] do
        nil -> []
        raw_encodings -> String.split(raw_encodings, ",") |> Enum.map(&String.trim(&1))
      end

    case Enum.member?(encodings, "gzip") do
      true ->
        compressed_data = :zlib.gzip(data)

        "HTTP/1.1 200 OK\r\n" <>
          "Content-Encoding: gzip\r\n" <>
          "Content-Type: #{content_type}\r\n" <>
          "Content-Length: #{byte_size(compressed_data)}\r\n\r\n" <>
          compressed_data

      _ ->
        "HTTP/1.1 200 OK\r\n" <>
          "Content-Type: #{content_type}\r\n" <>
          "Content-Length: #{byte_size(data)}\r\n\r\n" <>
          data
    end
  end

  def storage_directory() do
    {parsed, _, _} = OptionParser.parse(System.argv(), strict: [directory: :string])
    parsed[:directory]
  end
end

defmodule HTTPParser do
  def parse(request) do
    [header_section, body] = String.split(request, "\r\n\r\n", parts: 2)

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
