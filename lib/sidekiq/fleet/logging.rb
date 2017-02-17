require 'time'
require 'logger'
require 'fcntl'

module Sidekiq
  module Fleet
    module Logging
      class Pretty < Logger::Formatter
      end
    end
  end
end
