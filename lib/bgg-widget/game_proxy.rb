# frozen_string_literal: true

require 'json/add/ostruct'

class GameProxy < OpenStruct
  def to_json(*args)
    self.as_json['t'].to_json(*args)
  end

  def proxy?
    true
  end
end
