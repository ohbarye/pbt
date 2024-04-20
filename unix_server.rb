# server.rb
require "socket"

# UNIXドメインソケットを作成
socket_path = "/tmp/ruby_socket"
File.unlink(socket_path) if File.exist?(socket_path)
server = UNIXServer.new(socket_path)

puts "Server is listening on #{socket_path}"

# クライアントからの接続を待機
loop do
  client = server.accept

  # クライアントからのデータを受信
  _request = client.gets

  # クライアントにレスポンスを送信
  response = "Hello, client!\n"
  client.puts(response)

  # クライアントとの接続を閉じる
  client.close
end
