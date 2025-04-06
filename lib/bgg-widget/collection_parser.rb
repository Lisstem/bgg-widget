# frozen_string_literal: true

require 'nokogiri'

require_relative 'parsing_exception'
require_relative 'game_proxy'
require_relative 'routes'

class Collection < OpenStruct
  def to_json(*args)
    self.as_json['t'].to_json(*args)
  end

  def resolve_proxies
    games = self.games
    return self unless games

    non_proxies = games.reject(&:proxy?)
    non_proxies.each_with_object(non_proxies.group_by(&:id).to_h) do |game, map|
      game.base_games&.map! { |base_game| map[base_game.id]&.first || base_game }
    end

    self
  end

  def reverse_dependencies
    self.games&.each do |game|
      if game.base_games
        game.base_games.each do |base_game|
          base_game.extensions ||= []
          base_game.extensions << game
        end
        game.delete_field :base_games
      end
    end
    self
  end
end

class CollectionParser
  def parse(xml, user)
    items_container = Nokogiri::XML(xml).at('items')
    raise ParsingException.new("No items in collection:\n#{xml.inspect}") unless items_container

    items = items_container.children.filter('item')

    raise ParsingException.new('Invalid collection format') if items_container['totalitems'].to_i != items.count

    Collection.new(user: user, games: items.map { |i| parse_item(i) }, link: Routes.collection_uri(user))
  end

  private

  def parse_item(item)
    raise ParsingException('Invalid format for item in collection') unless item['objectid'].to_i > 0

    GameProxy.new(id: item['objectid'].to_i)
  end
end
