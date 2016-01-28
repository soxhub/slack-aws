module SlackAws
  module Commands
    class OpsWorks < SlackRubyBot::Commands::Base
      extend SlackAws::Util::AwsClientResponse

      command 'ops' do |client, data, match|
        arguments = match['expression'].split.reject(&:blank?) if match.names.include?('expression')
				@@current_stack = "" unless defined? @@current_stack
        case arguments && arguments.shift
				when 'reset' then
					@@current_stack = ""
					@@current_stack_id = ""
					
        when 'stack' then
					@@stacks = Aws::OpsWorks::Client.new.describe_stacks
					#@@stacks = Hash[response.stacks.map { |stack| [stack.name, stack.stack_id] }] unless defined? @@stacks
					stack_cmd = arguments.shift
					stack_cmd = "help" unless defined? stack_cmd
					
					case stack_cmd
						when 'ls' then
							send_fields client, data.channel, @@stacks.stacks, *[:name, :created_at].concat(arguments)
					
						when 'use' then
							use_stack = arguments.shift
							fail 'Invalid stack name.  Use `aws ops stack ls` to see available stacks' unless use_stack
							
							stack_hash = Hash[@@stacks.stacks.map { |stack| [stack.name, stack.stack_id] }]
							use_stack_id = stacks[use_stack]
							fail "Invalid stack: #{use_stack}.  Use `aws ops stack ls` to view available stacks." unless use_stack_id
							
							@@current_stack = use_stack
							@@current_stack_id = use_stack_id
							
							send_message client, data.channel, "Current Stack: **#{@@current_stack}** (id: **#{@@current_stack_id}**)" 
							send_message client, data.channel, "Instance commands are now available.  Syntax: aws ops instance help"

						when 'cwd' then
							fail 'No stack is selected! Select a stack using `aws ops stack use <stack>`.' if @@current_stack.empty?
							send_message client, data.channel, "Current Stack: **#{@@current_stack}** (id: **#{@@current_stack_id}**)" 
							
						when 'help' then
							send_message client, data.channel, "`aws ops stack <command>`"
							send_message client, data.channel, "stack commands: `ls`,  `use <stack>`,  `cwd`,  `help`"
							
					end
					
				when 'instance' then
					fail 'No stack is selected! Select a stack using `aws ops stack use <stack>` before using instance commands.' if @@current_stack.empty? || @@current_stack_id.empty?
					
					opsworks_client = Aws::OpsWorks::Client.new
					response = opsworks_client.describe_instances(stack_id: @@current_stack_id)
					
					instance_cmd = arguments.shift
					instance_cmd = "help" unless defined? instance_cmd
					
					case instance_cmd
						when 'ls' then
							send_fields client, data.channel, response.instances, *[:hostname, :instance_id, :instance_type, :status, :public_dns, :created_at].concat(arguments)
					
						when 'help' then
							
							send_message client, data.channel, "`aws ops instance <command>`"
							send_message client, data.channel, "instance commands: `ls`, `start <name>`, `stop <name>`, `deploy <name>`, `provision <name>`"
							send_message client, data.channel, "Current Stack: **#{@@current_stack}**" 
					end
					
					
          
        when 'apps' then
          opsworks_client = Aws::OpsWorks::Client.new
          stacks = Hash[opsworks_client.describe_stacks.stacks.map { |stack| [stack.name, stack.stack_id] }]
          stack_name = arguments.shift
          fail 'Syntax: aws opsworks apps [stack]' unless stack_name
          stack_id = stacks[stack_name]
          fail "Invalid stack: #{stack_name}" unless stack_id
          send_fields client, data.channel, opsworks_client.describe_apps(stack_id: stack_id).apps, *[:shortname, :name, :description, :created_at].concat(arguments)
        when 'instances' then
          opsworks_client = Aws::OpsWorks::Client.new
          stacks = Hash[opsworks_client.describe_stacks.stacks.map { |stack| [stack.name, stack.stack_id] }]
          stack_name = arguments.shift
          fail 'Syntax: aws opsworks instances [stack]' unless stack_name
          stack_id = stacks[stack_name]
          fail "Invalid stack: #{stack_name}" unless stack_id
          send_fields client, data.channel, opsworks_client.describe_instances(stack_id: stack_id).instances, *[:hostname, :instance_id, :instance_type, :status, :public_dns, :created_at].concat(arguments)
				when 'start' then
					opsworks_client = Aws::OpsWorks::Client.new
					stacks = Hash[opsworks_client.describe_stacks.stacks.map { |stack| [stack.name, stack.stack_id] }]
          stack_name = arguments.shift
          fail 'Syntax: aws opsworks start [stack] [instance_id]' unless stack_name
					stack_id = stacks[stack_name]
          fail "Invalid stack: #{stack_name}" unless stack_id
					instance_id = arguments.shift
					fail 'Error: instance_id cannot be blank. Syntax: aws opsworks start [stack] [instance_id]' unless instance_id
					response = opsworks_client.start_instance(instance_id: instance_id)
					puts response.inspect
					send_message client, data.channel, "Starting instance #{stack_name} : #{instance_id}"
					
				when 'stop' then
					opsworks_client = Aws::OpsWorks::Client.new
					stacks = Hash[opsworks_client.describe_stacks.stacks.map { |stack| [stack.name, stack.stack_id] }]
          stack_name = arguments.shift
          fail 'Syntax: aws opsworks stop [stack] [instance_id]' unless stack_name
					stack_id = stacks[stack_name]
          fail "Invalid stack: #{stack_name}" unless stack_id
					instance_id = arguments.shift
					fail 'Error: instance_id cannot be blank. Syntax: aws opsworks stop [stack] [instance_id]' unless instance_id
					response = opsworks_client.stop_instance(instance_id: instance_id)
					puts response.inspect
					send_message client, data.channel, "Stopping instance #{stack_name} : #{instance_id}"
					
				when 'test' then
					@@test_var = "" unless defined? @@test_var
					@@test_var += arguments.shift
					send_message client, data.channel, "#{@@test_var}"
					
        else
          send_message client, data.channel, 'Syntax: aws opsworks [command], need `aws help`?'
        end
      end
    end
  end
end
