require 'sinatra/base'

module SlackAws
  class Web < Sinatra::Base
    get '/' do
      'Slack integration with AWS.'
    end
  end
end
