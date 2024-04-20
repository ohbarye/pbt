require "pbt"
require "socket"
require "benchmark/ips"

def unix
  # サーバへ接続
  socket_path = "/tmp/ruby_socket"
  client = UNIXSocket.new(socket_path)

  # サーバにデータを送信
  request = "Hello, server!\n"
  client.puts(request)

  # サーバからのレスポンスを受信
  _response = client.gets

  # サーバとの接続を閉じる
  client.close
end

def tcp
  host = "127.0.0.1"
  port = 10001

  socket = TCPSocket.open(host, port)
  request = "GET / HTTP/1.1\r\nHost: #{host}\r\n\r\n"
  socket.print(request)
  _response = socket.read

  socket.close
end

seed = 17243810592888013452170775373100387856

Benchmark.ips do |x|
  x.report("ractor") do
    Pbt.assert(worker: :ractor, seed:) do
      Pbt.property(Pbt.ascii_string) do |_|
        tcp
      end
    end
  end

  x.report("process") do
    Pbt.assert(worker: :process, seed:) do
      Pbt.property(Pbt.ascii_string) do |_|
        tcp
      end
    end
  end

  x.report("thread") do
    Pbt.assert(worker: :thread, seed:) do
      Pbt.property(Pbt.ascii_string) do |_|
        tcp
      end
    end
  end

  x.report("none") do
    Pbt.assert(worker: :none, seed:) do
      Pbt.property(Pbt.ascii_string) do |_|
        tcp
      end
    end
  end
end
