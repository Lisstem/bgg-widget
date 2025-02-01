require 'bundler/setup'
require 'concurrent/promises'

require_relative 'downloader'
require_relative 'collection_parser'
require_relative 'routes'

user = ARGV[0]

unless user
  puts "Error: no user given\nUsage: ruby build-list.rb <user>"
  exit 1
end

downloader = Downloader.new
downloader.start

retry_on202 = ->(response) do
  if response.code.to_i == 202
    puts "Got 202 for #{response.uri.to_s.inspect}. Retrying..."
    sleep 10
    downloader.enq(response.uri)
  else
    Concurrent::Promises.fulfilled_future(response)
  end
end

reject_errors = ->(response) do
  raise "Got #{response.code} for #{response.uri.to_s.inspect}" if response.code.to_i != 200

  response
end

collection_parser = CollectionParser.new

parse_collection = ->(response) do
  puts response.inspect
  puts "Parsing #{response.uri.to_s.inspect}..."
  { uri: response.uri, game_ids: collection_parser.parse(response.body) }
end

printer = ->(data) { puts data.inspect }



downloader
  .enq(Routes::collection_of(user))
  .then(&retry_on202).flat
  .then(&reject_errors)
  .then(&parse_collection)
  .then(&printer)
#downloader.enq('/xmlapi2/thing?id=28143').then(&reject_errors).then &printer

downloader.stop

