require "socket"

# 待ち受けるポート番号を指定
port = 10001

# TCPサーバを作成
server = TCPServer.new(port)

# 接続を待ち受ける
loop do
  # クライアントからの接続を受け付ける
  client = server.accept

  # クライアントのIPアドレスとポートを取得
  _client_ip = client.peeraddr[3]
  _client_port = client.peeraddr[1]

  # クライアントからのデータを受信
  _request = client.gets

  # クライアントにレスポンスを送信
  response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nHello, world!\n"
  client.print(response)

  # クライアントとの接続を閉じる
  client.close
end
