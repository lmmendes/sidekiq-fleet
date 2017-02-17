require "sidekiq/fleet/version"
require "sidekiq/fleet/client"

module Sidekiq
  module Fleet
    def self.new(options = {})
      Sidekiq::Fleet::Client.new(options)
    end
  end
end
