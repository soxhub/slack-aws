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
					
				when 'help' then
					send_message client, data.channel, "use `aws ops stack help` for help with stack commands, and `aws ops instance help` for help with instance commands."

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
							
							stack_hash = Hash[@@stacks.stacks.map { |s| [s.name, s] }]
							stack = stack_hash[use_stack]
							fail "Invalid stack: #{use_stack}.  Use `aws ops stack ls` to view available stacks." unless stack
							
							@@current_stack = use_stack
							@@current_stack_id = stack.stack_id
							
							opsworks_client = Aws::OpsWorks::Client.new;
							@@layers = opsworks_client.describe_layers(stack_id: @@current_stack_id)
							@@layer_ids = @@layers.layers.map { |lyr| lyr.layer_id }
							
							send_message client, data.channel, "current stack: *#{@@current_stack}*" 
							send_message client, data.channel, "Instance commands are now available.  Use `aws ops instance help` to view available commands."

						when 'cwd' then
							fail 'No stack is selected! Select a stack using `aws ops stack use <stack>`.' if @@current_stack.empty?
							send_message client, data.channel, "current stack: *#{@@current_stack}*" 
							
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
					
						when 'start' then
							start_instance = arguments.shift
							fail 'Invalid instance name.  Use `aws ops instance ls` to see available instances in stack *#{@@current_stack}*' unless start_instance
							
							instance_hash = Hash[response.instances.map { |instance| [instance.hostname, instance] }]
							instance = instance_hash[start_instance]
							fail "Invalid instance: #{start_instance}.  Use `aws ops instance ls` to see available instances." unless instance

							fail "Failed to start instance *#{start_instance}*.  Instance is not currently in status *stopped*." unless instance.status == "stopped"
							
							start_response = opsworks_client.start_instance(instance_id: instance.instance_id)
							send_message client, data.channel, "starting instance *#{instance.hostname}* on stack *#{@@current_stack}*"
							send_message client, data.channel, "use `aws ops instance ls` or login to opsworks to view the status of this operation."
							
						when 'stop' then
							
							fail 'this poor bot is not permitted to stop instances.  please stop instances directly through aws.'
							
							stop_instance = arguments.shift
							fail 'Invalid instance name.  Use `aws ops instance ls` to see available instances in stack *#{@@current_stack}*' unless stop_instance
							
							instance_hash = Hash[response.instances.map { |instance| [instance.hostname, instance] }]
							instance = instance_hash[stop_instance]
							fail "Invalid instance: #{stop_instance}.  Use `aws ops instance ls` to see available instances." unless instance

							#fail "Failed to stop instance *#{stop_instance}*.  Instance is not currently in status *stopped*." unless instance.status == "stopped"
							
							start_response = opsworks_client.stop_instance(instance_id: instance.instance_id)
							send_message client, data.channel, "stopping instance *#{instance.hostname}* on stack *#{@@current_stack}*"
							send_message client, data.channel, "use `aws ops instance ls` or login to opsworks to view the status of this operation."
							
						when 'create' then
							create_instance = arguments.shift
							fail 'Invalid instance name.  Use `aws ops instance ls` to see available instances in stack *#{@@current_stack}*.  Instances must have unique hostnames.' unless create_instance
							
							instance_hash = Hash[response.instances.map { |instance| [instance.hostname, instance] }]
							instance = instance_hash[create_instance]
							fail "Instance *#{create_instance}* already exists.  Use `aws ops instance ls` to see existing instances.  Newly created instances must have unique hostnames" if instance
							
							create_response = opsworks_client.create_instance(stack_id: @@current_stack_id, layer_ids: @@layer_ids, instance_type: 't2.medium', hostname: create_instance, os: 'Ubuntu 14.04 LTS', ssh_key_name: 'kevin-jhangiani-soxhub')
							
							send_message client, data.channel, "creating instance *#{create_instance}* on stack *#{@@current_stack}*"
							send_message client, data.channel, "use `aws ops instance ls` or login to opsworks to view the status of this operation."
						
						when 'status' then
							status_instance = arguments.shift
							fail 'Invalid instance name.  Use `aws ops instance ls` to see available instances in stack *#{@@current_stack}*.' unless status_instance
							
							instance_hash = Hash[response.instances.map { |inst| [inst.hostname, inst] }]
							instance = instance_hash[status_instance]
							fail "Instance *#{status_instance}* does not exist.  Use `aws ops instance ls` to see existing instances." unless instance
							
							status_response = opsworks_client.describe_commands(instance_id: instance.instance_id)
							
							
							send_message client, data.channel, "current stack: *#{@@current_stack}*" 
							send_message client, data.channel, "hostname=*#{instance.hostname}*,instance_id=*#{instance.instance_id}*,status=*#{instance.status}*,instance_type=*#{instance.instance_type}*"
							send_fields client, data.channel, status_response.commands, *[:type, :status, :command_id, :exit_code, :log_url, :created_at, :completed_at].concat(arguments)
							
						when 'provision' then
							provision_hostname = arguments.shift
							fail 'Invalid instance name.  Use `aws ops instance ls` to see available instances in stack *#{@@current_stack}*.' unless provision_hostname
							
							instance_hash = Hash[response.instances.map { |instance| [instance.hostname, instance] }]
							instance = instance_hash[provision_hostname]
							fail "Instance *#{provision_hostname}* does not exist.  Use `aws ops instance ls` to see existing instances." unless instance
							
							commands = opsworks_client.describe_commands(instance_id: instance.instance_id).commands
							fail "another command is currently running.  please wait for the prior command to complete before provisioning.  the prior command is in status *#{commands[0].status}*" if commands.size && commands[0].status != "successful" && commands[0].status != "failed"
							
							api_branch = arguments.shift
							api_branch = "staging" if !api_branch || api_branch.empty?
							
							client_branch = arguments.shift
							client_branch = "staging" if !client_branch || client_branch.empty?
							
							fail "api branch cannot be empty" if !api_branch || api_branch.empty?
							fail "client branch cannot be empty" if !client_branch || client_branch.empty?
							
							deploy_response = opsworks_client.create_deployment(stack_id: @@current_stack_id, instance_ids:[instance.instance_id], command: { name: 'execute_recipes', args: { recipes: ["soxhub::provision_soxhub_instances"] }}, custom_json: "{\"soxhub\":{\"instances\":[{\"appname\":\"#{provision_hostname}\", \"api_branch\":\"#{api_branch}\", \"client_branch\":\"#{client_branch}\"}]}}")
							
							# create_response = opsworks_client.create_instance(stack_id: @@current_stack_id, layer_ids: @@layer_ids, instance_type: 't2.small', hostname: create_instance, os: 'Ubuntu 14.04 LTS', ssh_key_name: 'kevin-jhangiani-soxhub')
							
							send_message client, data.channel, "DEPLOYING APP! api: `#{api_branch}` client: `#{client_branch}`"
							send_message client, data.channel, "instance: *#{provision_hostname}*, stack: *#{@@current_stack}*"
							send_message client, data.channel, "use `aws ops instance status #{provision_hostname}` or login to opsworks to view the status of this operation."

					
						when 'help' then
							send_message client, data.channel, "`aws ops instance <command>`"
							send_message client, data.channel, "instance commands: `ls`, `start <name>`, `stop <name>`, `status <name>`, `create <name>`, `provision <name> <api_branch|default:staging> <client_branch|default:staging>`"
							send_message client, data.channel, "current stack: *#{@@current_stack}*" 
							
					end
					
					
          
        # when 'apps' then
          # opsworks_client = Aws::OpsWorks::Client.new
          # stacks = Hash[opsworks_client.describe_stacks.stacks.map { |stack| [stack.name, stack.stack_id] }]
          # stack_name = arguments.shift
          # fail 'Syntax: aws opsworks apps [stack]' unless stack_name
          # stack_id = stacks[stack_name]
          # fail "Invalid stack: #{stack_name}" unless stack_id
          # send_fields client, data.channel, opsworks_client.describe_apps(stack_id: stack_id).apps, *[:shortname, :name, :description, :created_at].concat(arguments)
        # when 'instances' then
          # opsworks_client = Aws::OpsWorks::Client.new
          # stacks = Hash[opsworks_client.describe_stacks.stacks.map { |stack| [stack.name, stack.stack_id] }]
          # stack_name = arguments.shift
          # fail 'Syntax: aws opsworks instances [stack]' unless stack_name
          # stack_id = stacks[stack_name]
          # fail "Invalid stack: #{stack_name}" unless stack_id
          # send_fields client, data.channel, opsworks_client.describe_instances(stack_id: stack_id).instances, *[:hostname, :instance_id, :instance_type, :status, :public_dns, :created_at].concat(arguments)
				# when 'start' then
					# opsworks_client = Aws::OpsWorks::Client.new
					# stacks = Hash[opsworks_client.describe_stacks.stacks.map { |stack| [stack.name, stack.stack_id] }]
          # stack_name = arguments.shift
          # fail 'Syntax: aws opsworks start [stack] [instance_id]' unless stack_name
					# stack_id = stacks[stack_name]
          # fail "Invalid stack: #{stack_name}" unless stack_id
					# instance_id = arguments.shift
					# fail 'Error: instance_id cannot be blank. Syntax: aws opsworks start [stack] [instance_id]' unless instance_id
					# response = opsworks_client.start_instance(instance_id: instance_id)
					# puts response.inspect
					# send_message client, data.channel, "Starting instance #{stack_name} : #{instance_id}"
					
				# when 'stop' then
					# opsworks_client = Aws::OpsWorks::Client.new
					# stacks = Hash[opsworks_client.describe_stacks.stacks.map { |stack| [stack.name, stack.stack_id] }]
          # stack_name = arguments.shift
          # fail 'Syntax: aws opsworks stop [stack] [instance_id]' unless stack_name
					# stack_id = stacks[stack_name]
          # fail "Invalid stack: #{stack_name}" unless stack_id
					# instance_id = arguments.shift
					# fail 'Error: instance_id cannot be blank. Syntax: aws opsworks stop [stack] [instance_id]' unless instance_id
					# response = opsworks_client.stop_instance(instance_id: instance_id)
					# puts response.inspect
					# send_message client, data.channel, "Stopping instance #{stack_name} : #{instance_id}"
					
				# when 'test' then
					# @@test_var = "" unless defined? @@test_var
					# @@test_var += arguments.shift
					# send_message client, data.channel, "#{@@test_var}"
					
        else
          send_message client, data.channel, 'Syntax: aws opsworks [command], need `aws help`?'
        end
      end
    end
  end
end
