# frozen_string_literal: true

require 'net/http'
require 'concurrent/promises'

class Downloader
  def initialize
    @input = Thread::Queue.new
    @thread = nil
  end

  def start
    return unless @thread.nil?

    @thread = Thread.new { self.do_download }
  end

  def stop
    @input.close
    @thread.join unless @thread.nil?
  end

  def enq(path)
    future = Concurrent::Promises.resolvable_future
    @input.push(future: future, path: path)

    future
  end

  private

  def do_download
    Net::HTTP.start(Routes::DOMAIN, use_ssl: true) do |html|
      input = @input.pop
      until input.nil? do
        puts "Downloading #{input[:path].inspect}..."
        response = html.get(input[:path])
        if response.is_a?(Net::HTTPRedirection)
          uri = URI(response['Location'])
          input[:path] = "#{uri.path}#{"?#{uri.query}" if uri.query}#{"##{uri.fragment}" if uri.fragment}"
          puts "Redirected to #{uri}..."
          @input.push(**input)
        else
          response.instance_variable_set(:@uri, URI("https://#{Routes::DOMAIN}#{input[:path]}"))
          input[:future].fulfill(response)
        end
        sleep(0.1)
        input = @input.pop
      end
    end
  end
end
