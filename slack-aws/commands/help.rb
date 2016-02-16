module SlackAws
  module Commands
    class Help < SlackRubyBot::Commands::Base
      command 'help' do |client, data, _match|
        send_message client, data.channel, 'Use `aws ops instance help` to view instance commands or `aws ops stack help` to view stack commands.'
      end
    end
  end
end
