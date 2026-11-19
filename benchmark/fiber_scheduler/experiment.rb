# frozen_string_literal: true

require "pbt"
require "async"
require "socket"

# Benchmark only: does not execute Pbt.check or implement a public worker.
module SchedulerExperiment
  # One server thread delays each response independently. It never uses a Fiber
  # scheduler, so all three client modes see the same delayed TCP protocol.
  class Server
    attr_reader :port

    def initialize(num_runs:, delay:)
      @listener = TCPServer.new("127.0.0.1", 0)
      @port = @listener.addr[1]
      @thread = Thread.new { serve(num_runs, delay) }
    end

    def serve(num_runs, delay)
      pending = {}
      completed = 0
      peak = 0
      until completed == num_runs
        timeout = pending.empty? ? nil : [pending.values.min - SchedulerExperiment.now, 0].max
        if IO.select([@listener], nil, nil, timeout)
          loop do
            socket = @listener.accept_nonblock(exception: false)
            break if socket == :wait_readable
            pending[socket] = SchedulerExperiment.now + delay
            peak = [peak, pending.size].max
          end
        end
        pending.keys.each do |socket|
          next if pending.fetch(socket) > SchedulerExperiment.now
          socket.write("ok")
          socket.close
          pending.delete(socket)
          completed += 1
        end
      end
      peak
    ensure
      pending&.each_key { |socket| socket.close unless socket.closed? }
    end

    def peak
      @thread.value
    end

    def close
      @thread.kill if @thread.alive?
      @thread.join
      @listener.close
    end
  end

  def self.now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def self.measure(mode:, num_runs:, concurrency:, delay:)
    raise ArgumentError, "existing scheduler must not be replaced" if Fiber.scheduler
    raise ArgumentError, "unknown mode" unless [:sequential, :fiber, :scheduler].include?(mode)
    raise ArgumentError, "positive runs and concurrency required" unless num_runs.positive? && concurrency.positive?

    rng = Random.new(42)
    values = Array.new(num_runs) { Pbt.integer(min: 0, max: 1000).generate(rng) }
    property = Pbt.property(Pbt.integer) { |value| yield(value) if block_given? }
    server = Server.new(num_runs: num_runs, delay: delay)
    observed = Array.new(num_runs)
    request = lambda do |index|
      socket = TCPSocket.new("127.0.0.1", server.port)
      raise "incorrect response" unless socket.read(2) == "ok"
      property.run(values.fetch(index))
      observed[index] = values.fetch(index)
    ensure
      socket&.close
    end

    started = now
    if mode == :scheduler
      Async do |parent|
        (0...num_runs).each_slice(concurrency) do |batch|
          tasks = []
          begin
            batch.each { |index| tasks << parent.async { request.call(index) } }
            tasks.each(&:wait)
          ensure
            tasks.each(&:stop)
          end
        end
      end.wait
    else
      num_runs.times do |index|
        if mode == :fiber
          Fiber.new { request.call(index) }.resume
        else
          request.call(index)
        end
      end
    end
    elapsed = now - started
    raise "incorrect generated inputs" unless observed == values
    {elapsed: elapsed, values: observed, completed: observed.size, max_pending: server.peak}
  ensure
    server&.close
  end

  def self.run(num_runs: 100, concurrency: 10, delay: 0.01, repeats: 5)
    raise ArgumentError, "repeats must be a positive odd number" unless repeats.positive? && repeats.odd?

    puts "Ruby #{RUBY_VERSION}; async #{Async::VERSION}; #{num_runs} cases; seed 42; delay #{delay}s; concurrency #{concurrency}; #{repeats} repeats"
    [:sequential, :fiber, :scheduler].each do |mode|
      # Warm up separately; exclude startup/gem loading from each timed request loop.
      measure(mode: mode, num_runs: concurrency, concurrency: concurrency, delay: delay)
      results = Array.new(repeats) { measure(mode: mode, num_runs: num_runs, concurrency: concurrency, delay: delay) }
      times = results.map { |result| result.fetch(:elapsed) }
      puts "#{mode}: seconds=#{times.map { |time| format("%.6f", time) }.join(",")}; median=#{format("%.6f", times.sort.fetch(repeats / 2))}; completed=#{results.map { |r| r.fetch(:completed) }.uniq.inspect}; max_pending=#{results.map { |r| r.fetch(:max_pending) }.inspect}; checksum=#{results.first.fetch(:values).sum}"
    end
  end
end

if $PROGRAM_NAME == __FILE__
  SchedulerExperiment.run(
    num_runs: Integer(ENV.fetch("NUM_RUNS", "100")),
    concurrency: Integer(ENV.fetch("CONCURRENCY", "10")),
    delay: Float(ENV.fetch("IO_DELAY", "0.01")),
    repeats: Integer(ENV.fetch("REPEATS", "5"))
  )
end
