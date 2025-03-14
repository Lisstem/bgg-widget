# frozen_string_literal: true

require 'nokogiri'
require 'json/add/ostruct'

require_relative 'game_proxy'
require_relative 'routes'

class Game < OpenStruct
  def to_json(*args)
    json_obj = self.as_json['t']
    puts json_obj[:base_games]&.map!(&:id)
    json_obj.to_json(*args)
  end

  def proxy?
    false
  end
end

class GameParser
  def parse_list(xml)
    games_container = Nokogiri::XML(xml).at('items')
    raise ParsingException.new("No items in game list:\n#{xml.inspect}") unless games_container

    games = games_container.children.filter('item')

    games.map { |game| parse_game(game) }
  end

  private

  def parse_game(game_raw)
    id = game_raw['id']&.to_i
    raise ParsingException.new("No id for game found:\n#{game_raw.inspect}") unless id

    name = game_raw.search("name[@type='primary']").first&.attr('value')
    raise ParsingException.new("No name for game found:\n#{game_raw.inspect}") unless name

    Game.new(**{
      id: id,
      name: name,
      thumbnails: game_raw.search('thumbnail').map {|t| t&.content&.strip },
      images: game_raw.search('image').map {|t| t&.content&.strip },
      description: game_raw.search('description').first&.content&.strip,
      year: game_raw.search('yearpublished').first&.attr('value')&.to_i,
      players: parse_players(game_raw),
      playing_time: parse_playing_time(game_raw),
      base_games: parse_base_games(game_raw),
      link: Routes::boardgame_uri(id)
    }.reject { |_, v| v.nil? })
  end

  private

  def parse_players(game_raw)
    players = {
      min: game_raw.search('minplayers').first&.attr('value')&.to_i,
      max: game_raw.search('maxplayers').first&.attr('value')&.to_i
    }.reject { |_, v| v.nil? }
    players.empty? ? nil : players
  end

  def parse_playing_time(game_raw)
    playing_time = {
      average: game_raw.search('playingtime').first&.attr('value')&.to_i,
      min: game_raw.search('minplaytime').first&.attr('value')&.to_i,
      max: game_raw.search('maxplaytime').first&.attr('value')&.to_i
    }.reject { |_, v| v.nil? }
    playing_time.empty? ? nil : playing_time
  end

  def parse_base_games(game_raw)
    base_games = game_raw.search("link[@type='boardgameexpansion'][@inbound='true']")
            .map {|link| link.attr('id')&.to_i }
            .reject(&:nil?)
            .map { |id| GameProxy.new(id: id) }

    base_games.empty? ? nil : base_games
  end
end
