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
          send_message client, data.channel, 'Use `aws ops instance help` to view instance commands or `aws ops stack help` to view stack commands.'

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
              
            when 'ucc' then
              opsworks_client = Aws::OpsWorks::Client.new;
              
              fail 'No stack is selected! Select a stack using `aws ops stack use <stack>`.' if @@current_stack.empty?
              send_message client, data.channel, "update_custom_cookbooks on stack: *#{@@current_stack}*"
              
              instance_ids = opsworks_client.describe_instances(stack_id: @@current_stack_id).instances.map { |ins| ins.instance_id }
              ucc_response = opsworks_client.create_deployment(stack_id: @@current_stack_id, instance_ids:instance_ids, command: { name: 'update_custom_cookbooks' })

              send_message client, data.channel, "UPDATING COOKBOOKS for STACK!"
              send_message client, data.channel, "stack: *#{@@current_stack}*"
              
            when 'help' then
              send_message client, data.channel, "`aws ops stack <command>`"
              send_message client, data.channel, "stack commands: `ls`, `use <stack>`, `cwd`, `ucc`, `help`"
              
          end
          
        when 'instance' then
          fail 'No stack is selected! Select a stack using `aws ops stack use <stack>` before using instance commands.' if @@current_stack.empty? || @@current_stack_id.empty?
          
          opsworks_client = Aws::OpsWorks::Client.new
          response = opsworks_client.describe_instances(stack_id: @@current_stack_id)
          
          instance_cmd = arguments.shift
          instance_cmd = "help" unless defined? instance_cmd
          
          case instance_cmd
            when 'ls' then
              send_fields client, data.channel, response.instances, *[:hostname, :instance_type, :status, :created_at, :instance_id].concat(arguments)
          
            when 'start' then
              start_instance = arguments.shift
              fail 'Invalid instance name.  Use `aws ops instance ls` to see available instances in stack *#{@@current_stack}*' unless start_instance
              
              instance_hash = Hash[response.instances.map { |instance| [instance.hostname, instance] }]
              instance = instance_hash[start_instance]
              fail "Invalid instance: #{start_instance}.  Use `aws ops instance ls` to see available instances." unless instance

              fail "Failed to start instance *#{start_instance}*.  Instance is not currently in status *stopped*." unless instance.status == "stopped"
              
              start_response = opsworks_client.start_instance(instance_id: instance.instance_id)
              send_message client, data.channel, "starting instance *#{instance.hostname}* on stack *#{@@current_stack}*"
              send_message client, data.channel, "use `aws ops instance status #{instance.hostname}` or login to opsworks to view the status of this operation."
              
            when 'stop' then
              
              # fail 'this poor bot is not permitted to stop instances.  please stop instances directly through aws.'
              
              stop_instance = arguments.shift
              fail 'Invalid instance name.  Use `aws ops instance ls` to see available instances in stack *#{@@current_stack}*' unless stop_instance
              
              instance_hash = Hash[response.instances.map { |instance| [instance.hostname, instance] }]
              instance = instance_hash[stop_instance]
              fail "Invalid instance: #{stop_instance}.  Use `aws ops instance ls` to see available instances." unless instance

              #fail "Failed to stop instance *#{stop_instance}*.  Instance is not currently in status *stopped*." unless instance.status == "stopped"
              
              start_response = opsworks_client.stop_instance(instance_id: instance.instance_id)
              send_message client, data.channel, "stopping instance *#{instance.hostname}* on stack *#{@@current_stack}*"
              send_message client, data.channel, "use `aws ops instance status #{instance.hostname}` or login to opsworks to view the status of this operation."
              
            when 'create' then
              create_instance = arguments.shift
              fail 'Invalid instance name.  Use `aws ops instance ls` to see available instances in stack *#{@@current_stack}*.  Instances must have unique hostnames.' unless create_instance
              
              instance_hash = Hash[response.instances.map { |instance| [instance.hostname, instance] }]
              instance = instance_hash[create_instance]
              fail "Instance *#{create_instance}* already exists.  Use `aws ops instance ls` to see existing instances.  Newly created instances must have unique hostnames" if instance

              instance_type = arguments.shift
              instance_type = "t2.small" if !instance_type || instance_type.empty?
              
              create_response = opsworks_client.create_instance(stack_id: @@current_stack_id, layer_ids: @@layer_ids, instance_type: instance_type, hostname: create_instance, os: 'Ubuntu 14.04 LTS', ssh_key_name: 'kevin-jhangiani-soxhub')
              
              send_message client, data.channel, "creating instance *#{create_instance}* on stack *#{@@current_stack}* with type *#{instance_type}*"
              send_message client, data.channel, "use `aws ops instance start #{create_instance}` to start this instance."
              send_message client, data.channel, "use `aws ops instance ls` or login to opsworks to view the status of this operation."
              
            when 'delete' then
              hostname = arguments.shift
              fail 'Invalid instance name.  Use `aws ops instance ls` to see available instances in stack *#{@@current_stack}*.  Instances must have unique hostnames.' unless hostname
              
              instance_hash = Hash[response.instances.map { |instance| [instance.hostname, instance] }]
              instance = instance_hash[hostname]
              fail "Invalid instance: #{hostname}.  Use `aws ops instance ls` to see available instances." unless instance
              
              fail "Failed to delete instance *#{hostname}*.  Instance must be in status *stopped*.  Current status: *#{instance.status}*.  Use `aws ops instance stop #{hostname}` to stop this instance first." unless instance.status == "stopped"
              
              response = opsworks_client.delete_instance(instance_id: instance.instance_id)
              
              send_message client, data.channel, "deleting instance *#{hostname}* from stack *#{@@current_stack}*"
              send_message client, data.channel, "use `aws ops instance ls` or login to opsworks to view the status of this operation."
            
            when 'status' then
              status_instance = arguments.shift
              num_results = arguments.shift
              num_results = "5" if !num_results || num_results.empty?
              num_results = num_results.to_i
              num_results = 5 if num_results <= 0
              num_results = num_results - 1

              fail 'Invalid instance name.  Use `aws ops instance ls` to see available instances in stack *#{@@current_stack}*.' unless status_instance
              
              instance_hash = Hash[response.instances.map { |inst| [inst.hostname, inst] }]
              instance = instance_hash[status_instance]
              fail "Instance *#{status_instance}* does not exist.  Use `aws ops instance ls` to see existing instances." unless instance
              
              status_response = opsworks_client.describe_commands(instance_id: instance.instance_id)
              
              
              send_message client, data.channel, "current stack: *#{@@current_stack}*" 
              send_message client, data.channel, "hostname=*#{instance.hostname}*,instance_id=*#{instance.instance_id}*,status=*#{instance.status}*,instance_type=*#{instance.instance_type}*"
              send_fields client, data.channel, status_response.commands[0..num_results], *[:type, :status, :command_id, :exit_code, :created_at, :completed_at].concat(arguments)
              
            when 'ucc' then
              hostname = arguments.shift
              fail 'Invalid instance name.  Use `aws ops instance ls` to see available instances in stack *#{@@current_stack}*.' unless hostname
              
              instance_hash = Hash[response.instances.map { |instance| [instance.hostname, instance] }]
              instance = instance_hash[hostname]
              fail "Instance *#{hostname}* does not exist.  Use `aws ops instance ls` to see existing instances." unless instance
              
              commands = opsworks_client.describe_commands(instance_id: instance.instance_id).commands
              fail "Another command is currently running.  please wait for the prior command to complete before running this operation.  The prior command is in status *#{commands[0].status}*" if commands.size && commands[0].status != "successful" && commands[0].status != "failed"
              
              ucc_response = opsworks_client.create_deployment(stack_id: @@current_stack_id, instance_ids:[instance.instance_id], command: { name: 'update_custom_cookbooks' })

              send_message client, data.channel, "UPDATING COOKBOOKS!"
              send_message client, data.channel, "instance: *#{hostname}*, stack: *#{@@current_stack}*"
              send_message client, data.channel, "use `aws ops instance status #{hostname}` or login to opsworks to view the status of this operation."
              
            when 'provision' then
              provision_hostname = arguments.shift
              fail 'Invalid instance name.  Use `aws ops instance ls` to see available instances in stack *#{@@current_stack}*.' unless provision_hostname
              
              instance_hash = Hash[response.instances.map { |instance| [instance.hostname, instance] }]
              instance = instance_hash[provision_hostname]
              fail "Instance *#{provision_hostname}* does not exist.  Use `aws ops instance ls` to see existing instances." unless instance
              
              commands = opsworks_client.describe_commands(instance_id: instance.instance_id).commands
              fail "another command is currently running.  please wait for the prior command to complete before provisioning.  the prior command is in status *#{commands[0].status}*" if commands.size && commands[0].status != "successful" && commands[0].status != "failed"
              
              api_branch = arguments.shift
              api_branch = "live" if !api_branch || api_branch.empty?
              
              client_branch = arguments.shift
              client_branch = "live" if !client_branch || client_branch.empty?
              
              fail "api branch cannot be empty" if !api_branch || api_branch.empty?
              fail "client branch cannot be empty" if !client_branch || client_branch.empty?
              
              deploy_response = opsworks_client.create_deployment(stack_id: @@current_stack_id, instance_ids:[instance.instance_id], command: { name: 'execute_recipes', args: { recipes: ["soxhub::provision"] }}, custom_json:"{\"soxhub\": { \"provision\": { \"instances\": { \"#{provision_hostname}\": true },\"api_branch\": \"#{api_branch}\",\"client_branch\": \"#{client_branch}\"}}}")
              
              # create_response = opsworks_client.create_instance(stack_id: @@current_stack_id, layer_ids: @@layer_ids, instance_type: 't2.small', hostname: create_instance, os: 'Ubuntu 14.04 LTS', ssh_key_name: 'kevin-jhangiani-soxhub')
              
              send_message client, data.channel, "DEPLOYING APP! api: `#{api_branch}` client: `#{client_branch}`"
              send_message client, data.channel, "instance: *#{provision_hostname}*, stack: *#{@@current_stack}*"
              send_message client, data.channel, "use `aws ops instance status #{provision_hostname}` or login to opsworks to view the status of this operation."

            when 'upgrade' then
              upgrade_hostname = arguments.shift
              fail 'Invalid instance name.  Use `aws ops instance ls` to see available instances in stack *#{@@current_stack}*.' unless upgrade_hostname
              
              instance_hash = Hash[response.instances.map { |instance| [instance.hostname, instance] }]
              instance = instance_hash[upgrade_hostname]
              fail "Instance *#{upgrade_hostname}* does not exist.  Use `aws ops instance ls` to see existing instances." unless instance
              
              commands = opsworks_client.describe_commands(instance_id: instance.instance_id).commands
              fail "another command is currently running.  please wait for the prior command to complete before upgrading.  the prior command is in status *#{commands[0].status}*" if commands.size && commands[0].status != "successful" && commands[0].status != "failed"
              
              api_branch = arguments.shift
              api_branch = "live" if !api_branch || api_branch.empty?
              
              client_branch = arguments.shift
              client_branch = "live" if !client_branch || client_branch.empty?
              
              fail "api branch cannot be empty" if !api_branch || api_branch.empty?
              fail "client branch cannot be empty" if !client_branch || client_branch.empty?
              
              upgrade_response = opsworks_client.create_deployment(stack_id: @@current_stack_id, instance_ids:[instance.instance_id], command: { name: 'execute_recipes', args: { recipes: ["soxhub::upgrade"] }}, custom_json:"{\"soxhub\": { \"upgrade\": { \"instances\": { \"#{upgrade_hostname}\": true },\"api_branch\": \"#{api_branch}\",\"client_branch\": \"#{client_branch}\"}}}")
              
              send_message client, data.channel, "UPGRADING APP! api: `#{api_branch}` client: `#{client_branch}`"
              send_message client, data.channel, "instance: *#{upgrade_hostname}*, stack: *#{@@current_stack}*"
              send_message client, data.channel, "use `aws ops instance status #{upgrade_hostname}` or login to opsworks to view the status of this operation."

              
            # @TODO: this fn needs additional checks on from_stack and from_instance
            when 'clonedb' then
              hostname = arguments.shift
              fail 'Invalid instance name.  Use `aws ops instance ls` to see available instances in stack *#{@@current_stack}*.' unless hostname
              
              instance_hash = Hash[response.instances.map { |instance| [instance.hostname, instance] }]
              instance = instance_hash[hostname]
              fail "Instance *#{hostname}* does not exist.  Use `aws ops instance ls` to see existing instances." unless instance
              
              commands = opsworks_client.describe_commands(instance_id: instance.instance_id).commands
              fail "another command is currently running.  please wait for the prior command to complete before upgrading.  the prior command is in status *#{commands[0].status}*" if commands.size && commands[0].status != "successful" && commands[0].status != "failed"
              
              from_stack = arguments.shift
              fail "<from> cannot be empty.  Use syntax `<stack>:<instance>` to specify which instance to clone from." if !from_stack || from_stack.empty?
              
              from_stack, from_instance = from_stack.split(':', 2)
              
              fail "<from_stack> cannot be empty. Use syntax `<stack>:<instance>` to specify which instance to clone from." if !from_stack || from_stack.empty?
              fail "<from_instance> cannot be empty. Use syntax `<stack>:<instance>` to specify which instance to clone from." if !from_instance || from_instance.empty?
              
              
              clone_response = opsworks_client.create_deployment(stack_id: @@current_stack_id, instance_ids:[instance.instance_id], command: { name: 'execute_recipes', args: { recipes: ["soxhub::clone_db"] }}, custom_json:"{\"soxhub\": { \"clone_db\": { \"instances\": { \"#{hostname}\": true }, \"from\": { \"stack\": \"#{from_stack}\", \"instance\":\"#{from_instance}\" } }}}")
              
              send_message client, data.channel, "CLONING DB FROM: stack: `#{from_stack}`, instance: `#{from_instance}`"
              send_message client, data.channel, "instance: *#{hostname}*, stack: *#{@@current_stack}*"
              send_message client, data.channel, "use `aws ops instance status #{hostname}` or login to opsworks to view the status of this operation."
              
            # @TODO: this fn needs additional checks
            when 'emptydb' then
              hostname = arguments.shift
              fail 'Invalid instance name.  Use `aws ops instance ls` to see available instances in stack *#{@@current_stack}*.' unless hostname
              
              instance_hash = Hash[response.instances.map { |instance| [instance.hostname, instance] }]
              instance = instance_hash[hostname]
              fail "Instance *#{hostname}* does not exist.  Use `aws ops instance ls` to see existing instances." unless instance
              
              commands = opsworks_client.describe_commands(instance_id: instance.instance_id).commands
              fail "another command is currently running.  please wait for the prior command to complete before upgrading.  the prior command is in status *#{commands[0].status}*" if commands.size && commands[0].status != "successful" && commands[0].status != "failed"
              
              empty_response = opsworks_client.create_deployment(stack_id: @@current_stack_id, instance_ids:[instance.instance_id], command: { name: 'execute_recipes', args: { recipes: ["soxhub::empty_db"] }}, custom_json:"{\"soxhub\": { \"empty_db\": { \"instances\": { \"#{hostname}\": true } }}}")
              
              send_message client, data.channel, "EMPTY DB operation started!"
              send_message client, data.channel, "instance: *#{hostname}*, stack: *#{@@current_stack}*"
              send_message client, data.channel, "use `aws ops instance status #{hostname}` or login to opsworks to view the status of this operation."
            
            when 'help' then
              send_message client, data.channel, "`aws ops instance <command>`"
              send_message client, data.channel, "instance commands: `ls`, `start <name>`, `stop <name>`, `status <name>`, `create <name> <type|default:t2.small>`,  `delete <name>`"
              send_message client, data.channel, "instance recipes: `ucc <name>`, `provision <name> <api_branch|default:live> <client_branch|default:live>`, `upgrade <name> <api_branch|default:live> <client_branch|default:live>`, `clonedb <name> <from_stack>:<from_instance>`, `emptydb <name>`"
              send_message client, data.channel, "current stack: *#{@@current_stack}*" 
              
          end
          
          
        else
          send_message client, data.channel, 'Syntax: aws ops [command], need `aws ops help`?'
        end
      end
    end
  end
end
