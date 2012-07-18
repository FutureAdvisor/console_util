require 'console_util/color'

module ConsoleUtil
  class << self
    attr_reader :suppressed_output
    
    # Monkey-patch the ActiveRecord connection to output the SQL query before
    # executing it.
    def output_sql_to_console(options = {})
      color = Color::CYAN
      if options[:color]
        raise ArgumentError.new("invalid color option: #{options[:color].inspect}") unless Color.valid_escape_code?(options[:color])
        color = options[:color]
      end

      ActiveRecord::Base.connection.class_eval do
        define_method(:execute) do |sql, *name|
          puts "#{color}#{sql}#{Color::RESET}"
          super
        end
      end
      
      true
    end
    
    # Import a MySQL dump file.
    # [This may work with other databases, but has only been tested with MySQL.]
    def import_mysql_dump(filename)
      sql_dump_file = File.open(Rails.root.join('sql', "#{filename}.sql"))
      while sql_statement = sql_dump_file.gets(";\n") do
        ActiveRecord::Base.connection.execute(sql_statement) unless sql_statement.blank?
      end
    end

    # Load all models into the environment
    def load_all_models
      Rails.root.join('app/models').each_entry do |model_file|
        model_match = model_file.to_s.match(/^(.*)\.rb$/)
        model_match[1].classify.constantize if model_match
      end
    end
    
    # Allows you to filter output to the console using grep
    # Ex:
    #   def foo
    #     puts "Some debugging output here"
    #     puts "The value of x is y"
    #     puts "The value of foo is bar"
    #   end
    # 
    #   grep_stdout(/value/) { foo }
    #   # => The value of x is y
    #   # => The value of foo is bar
    #   # => nil
    def grep_stdout(expression)
      # First we need to create a ruby "pipe" which is two sets of IO subclasses
      # the first is read only (which represents a fake $stdin) and the second is
      # write only (which represents a fake $stdout).
      placeholder_in, placeholder_out = IO.pipe
      
      # Fork off a child process to handle the block.  We do this in a child process
      # so that as soon as placeholder_out starts receiving data a second child
      # process can operate on it via placeholder_in
      pid_1 = fork {
        # replace $stdout with placeholder_out
        $stdout.reopen(placeholder_out)
        
        # we have to close both placeholder_out and placeholder_in because all instances
        # of an IO stream must be closed in order for it to ever reach EOF.  There's three
        # in this method; one in each child process and one in the main process.
        placeholder_out.close
        placeholder_in.close
        
        # sync $stdout so that we can start operating on it as soon as possible
        $stdout.sync
        
        # allow the block to execute
        yield
      }
      
      # This child process handles the grep'ing.  Its done in a child process so that
      # it can operate in parallel with the other one.
      pid_2 = fork {
        # sync $stdout so we can report any matches asap
        $stdout.sync
        
        # same as the first child process
        $stdin.reopen(placeholder_in)
        placeholder_in.close
        placeholder_out.close
        
        # loop continuously until we reach EOF (which happens when all
        # instances of placeholder_out have closed)
        read_buffer = ''
        loop do
          begin
            read_buffer << $stdin.readpartial(4096)
            if line_match = read_buffer.match(/(.*\n)(.*)/)
              print line_match[1].grep(expression)  # grep complete lines
              read_buffer = line_match[2]           # save remaining partial line for the next iteration
            end
          rescue EOFError
            read_buffer.grep(expression)  # grep any remaining partial line at EOF
            break
          end
        end
      }
      
      # close this processes instances of placeholder_in and placeholder_out
      placeholder_in.close
      placeholder_out.close
      
      # Wait for both child processes to finish
      Process.wait pid_1
      Process.wait pid_2
      
      # Because the connection to the database has a tendency to go away when calling this, reconnect here
      if defined?(ActiveRecord)
        suppress_stdout { ActiveRecord::Base.verify_active_connections! }
      end
      
      # return nil
      nil
    end

    # Allows you to suppress $stdout but allows you to send certain messages to $stdout
    # Ex:
    #   def foo
    #     puts "lots of stuff directed to $stdout that I don't want to see."
    #   end
    #   
    #   suppress_stdout do |stdout|
    #     stdout.puts "About to call #foo"
    #     foo
    #     stdout.puts "Called foo"
    #   end
    #   # => About to call #foo
    #   # => Called foo
    #   # => <# The result of #foo >
    def suppress_stdout
      original_stdout = $stdout
      $stdout = output_buffer = StringIO.new
      begin
        return_value = yield(original_stdout)
      ensure
        $stdout = original_stdout
        @suppressed_output ||= ""
        @suppressed_output << output_buffer.string
      end
      return_value
    end
  end
end
