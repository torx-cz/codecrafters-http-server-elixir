# HTTP server in Elixir
[![progress-banner](https://backend.codecrafters.io/progress/http-server/d62aefa2-1881-4474-b096-660b60fbf7d7)](https://app.codecrafters.io/users/codecrafters-bot?r=2qF)

## Dependencies
This project uses [devbox](https://www.jetify.com/docs/devbox/installing_devbox/https://www.jetpack.io/devbox/) to manage dependencies.

To install dependencies, run:

```bash
devbox shell
```

## Local Run
To run the server locally, you can use the following command:

```bash
./your_program.sh --direcotry /tmp
```

This will start the HTTP server. You can then interact with it using a tool like `curl`.

## Features

This HTTP server implementation in Elixir provides the following features:

### Endpoints

*   **GET /**: Response with `HTTP/1.1 200 OK\r\n\r\n`
*   **GET /user-agent**: Returns the User-Agent header sent by the client.
*   **GET /echo/{string}**: Returns the `string` from path as the body.
*   **GET /files/{filename}**: Serves the content of the file with the given filename located in the specified directory (vie `--directory` argument). If the file is not found, it returns a `404` error.
*   **POST /files/{filename}**: Creates a new file with the given filename in the specified directory (via `--directory` argument) and writes the request body to it. If the file already exists, it overwrites it.


### Other Features

*   **Gzip Compression**: The server supports Gzip compression for response bodies. If the client indicates support for Gzip encoding, like with `Accept-Encodings: gzip` headers.
*   **Concurrent Requests**: The server is designed to handle multiple concurrent requests efficiently, leveraging Elixir's concurrency model.


## Tests

You can test the server using `curl`. Here are a few examples:

### GET /

```bash
curl -v http://localhost:4221/
```

Expected response:

```
< HTTP/1.1 200 OK
```

### GET /user-agent

```bash
curl -v -H "User-Agent: MyTestClient/1.0" http://localhost:4221/user-agent
```

Expected response:

```
< HTTP/1.1 200 OK
MyTestClient/1.0
```

### GET /echo/hello

```bash
curl -v http://localhost:4221/echo/hello
```

Expected response:

```
< HTTP/1.1 200 OK
hello
```

### GET /files/my_file.txt (file exists)

First create a file:

```bash
echo "File content" > /tmp/my_file.txt
```

Then run:

```bash
curl -v http://localhost:4221/files/my_file.txt
```

Expected response:

```
< HTTP/1.1 200 OK
File content
```

### GET /files/non_existent.txt (file does not exist)

```bash
curl -v http://localhost:4221/files/non_existent.txt
```

Expected response:

```
< HTTP/1.1 404 Not Found
```

### POST /files/new_file.txt

```bash
curl -v -d "New file content" -H "Content-Type: application/octet-stream" http://localhost:4221/files/new_file.txt
```

Expected response:

```
< HTTP/1.1 201 Created
```

And verify the file content:

```bash
cat /tmp/new_file.txt
```

Expected output:

```
New file content
```

### Gzip compression

```bash
curl -v -H "Accept-Encoding: gzip" http://localhost:4221/echo/abc | hexdump -C
```

Expected response:

```
< HTTP/1.1 200 OK
< Content-Encoding: gzip
< Content-Type: text/plain
< Content-Length: 23

1f 8b 08 00 00 00 00 00
00 03 4b 4c 4a 06 00 c2
41 24 35 03 00 00 00
```
