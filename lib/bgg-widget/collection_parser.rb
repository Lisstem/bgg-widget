# frozen_string_literal: true

require 'nokogiri'

require_relative 'parsing_exception'

class CollectionParser
  def parse(xml)
    item_container = Nokogiri::XML(xml).at('items')
    raise ParsingException.new("No items in collection:\n#{xml.inspect}") unless item_container

    items = item_container.children.filter('item')

    raise ParsingException.new('Invalid collection format') if item_container['totalitems'].to_i != items.count

    items.map { |i| parse_item(i) }
  end

  private

  def parse_item(item)
    raise ParsingException('Invalid format for item in collection') unless item['objectid'].to_i > 0

    item['objectid'].to_i
  end
end
