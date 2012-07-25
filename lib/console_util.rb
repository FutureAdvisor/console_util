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
        model_match[1].camelize.constantize if model_match
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

      # This child process handles the grep'ing.  Its done in a child process so that
      # it can operate in parallel with the main process.
      pid = fork {
        # sync $stdout so we can report any matches asap
        $stdout.sync

        # replace $stdout with placeholder_out
        $stdin.reopen(placeholder_in)

        # we have to close both placeholder_out and placeholder_in because all instances
        # of an IO stream must be closed in order for it to ever reach EOF.  There's two
        # in this method; one in the child process and one in the main process.
        placeholder_in.close
        placeholder_out.close

        # loop continuously until we reach EOF (which happens when all
        # instances of placeholder_out have closed)
        read_buffer = ''
        loop do
          begin
            match     = nil
            next_read = $stdin.readpartial(4096)

            read_buffer << next_read
            if line_match = read_buffer.match(/^(.*\n)(.*)$/m)
              match = line_match[1].grep(expression)  # grep complete lines
              read_buffer = line_match[2]             # save remaining partial line for the next iteration
            end
          rescue EOFError
            match = read_buffer.grep(expression)      # grep any remaining partial line at EOF
            break
          end

          if match && !match.empty?
            print match
          end
        end
      }

      # Save the original stdout out to a variable so we can use it again after this
      # method is done
      original_stdout = $stdout

      # Redirect stdout to our pipe
      $stdout = placeholder_out

      # sync $stdout so that we can start operating on it as soon as possible
      $stdout.sync

      # allow the block to execute and save its return value
      return_value = yield

      # Set stdout back to the original so output will flow again
      $stdout = original_stdout

      # close the main instances of placeholder_in and placeholder_out
      placeholder_in.close
      placeholder_out.close

      # Wait for the child processes to finish
      Process.wait pid

      # Because the connection to the database has a tendency to go away when calling this, reconnect here
      # if we're using ActiveRecord
      if defined?(ActiveRecord)
        suppress_stdout { ActiveRecord::Base.verify_active_connections! }
      end

      # return the value of the block
      return_value
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
