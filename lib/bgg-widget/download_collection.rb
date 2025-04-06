require 'bundler/setup'
require 'concurrent/promises'
require 'json'

require_relative 'downloader'
require_relative 'collection_parser'
require_relative 'game_parser'
require_relative 'routes'

user = ARGV[0]

unless user
  puts "Error: no user given\nUsage: ruby download_collection.rb <user>"
  exit 1
end

downloader = Downloader.new
downloader.start

retry_on202 = ->(response) do
  if response.code.to_i == 202
    puts "Got 202 for #{response.uri.to_s.inspect}. Retrying..."
    sleep 10
    downloader.enq(response.uri).then(&retry_on202)
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
  puts "Parsing #{response.uri.to_s.inspect}..."
  collection_parser.parse(response.body, user)
end

fetch_games_chunk = ->(games) do
  ids = games.map(&:id)
  puts "Fetching chunk of games #{ids}..."
  downloader
    .enq(Routes.things(*ids))
    .then(&reject_errors)
    .then { |response| [response.body] }
end

game_parser = GameParser.new

parse_games = ->(games) do
  puts "Parsing games..."
  game_parser.parse_list(games)
end

fetch_games = ->(collection) do
  puts "Fetching games #{collection.games.map(&:id)}..."
  Concurrent::Promises.zip(*collection.games.each_slice(20).map(&fetch_games_chunk))
                      .then do |games_raw|
                          collection.games = games_raw.flat_map(&parse_games)
                          collection
                      end
end

save = ->(data) do
  file = "#{user}.json"
  puts "Saving to #{file}..."
  File.write("#{user}.json", data)
end

downloader
  .enq(Routes::collection_of(user))
  .then(&retry_on202).flat
  .then(&reject_errors)
  .then(&parse_collection)
  .then(&fetch_games).flat
  .then {|collection| collection.resolve_proxies.reverse_dependencies.to_json }
  .then(&save)
  .then { puts 'done' }
  .wait!

downloader.stop

