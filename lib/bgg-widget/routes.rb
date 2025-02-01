# frozen_string_literal: true

module Routes
  DOMAIN = 'boardgamegeek.com'

  class << self
    def collection_of(user)
      "/xmlapi2/collection?username=#{user}&own=1"
    end
  end
end
