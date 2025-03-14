# frozen_string_literal: true

module Routes
  DOMAIN = 'boardgamegeek.com'

  class << self
    def collection_of(user)
      "/xmlapi2/collection?username=#{user}&own=1"
    end

    def things(*ids)
      "/xmlapi2/thing?id=#{ids.join(',')}"
    end

    def collection_uri(user)
      "https://#{DOMAIN}/collection/user/#{user}"
    end

    def boardgame_uri(id)
      "https://#{DOMAIN}/boardgame/#{id}"
    end
  end
end
