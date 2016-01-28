module SlackAws
  module Commands
    class Help < SlackRubyBot::Commands::Base
      command 'help' do |client, data, _match|
        send_message client, data.channel, 'See README.md please.'
      end
    end
  end
end
