require 'console_util/color'

module ConsoleUtil
  class << self
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
      $stdout = fake = StringIO.new
      begin
        capture = yield(original_stdout)
      ensure
        $stdout = original_stdout
      end
      capture
    end
  end
end
