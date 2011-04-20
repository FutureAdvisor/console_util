module ConsoleUtil
  class Color
    @@colors = [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white]

    @@color_codes = {
      :reset        =>  0,  # Reset all current console color attributes.
      :bright       =>  1,  # Set intensity of current console foreground color to bright.
      :underline    =>  4,  # Underline console output.
      :blink        =>  5,  # Blink console output.
      :negative     =>  7,  # Invert the current console foreground and background colors.
      :normal       => 22,  # Set intensity of current console foreground color to normal.
      :no_underline => 24,  # Do not underline console output.
      :no_blink     => 25,  # Do not blink console output.
      :positive     => 27   # Do not invert the current console foreground and background colors.
    }

    @@fg_color_base = 30
    @@bg_color_base = 40

    # Define constants that return the ANSI escape codes corresponding to each
    # of the predefined color attributes.
    @@color_codes.each do |color_attr, code|
      color_const = color_attr.to_s.upcase
      self.class_eval <<-COLOR_CONST, __FILE__, __LINE__ + 1
        #{color_const} = "\e[#{code}m"
      COLOR_CONST
    end

    class << self
      # Used to create magic constants for every supported color combination.
      def const_missing(const)
        # Attempt to parse the method name as a color string.
        color_escape_code = convert_color_string(const.to_s)

        if color_escape_code
          # Define a constant for the ANSI escape code that corresponds to the
          # specified color and return it.
          self.class_eval <<-COLOR_CONST, __FILE__, __LINE__ + 1
            #{const} = "#{color_escape_code}"
          COLOR_CONST
        else
          super
        end
      end

      def valid_escape_code?(color_escape_code)
        !color_escape_code.match(/^\e\[[0-9;]*m$/).nil?
      end

    private
      def convert_color_string(color_string)
        bright = nil
        fg = nil
        bg = nil

        # Parse the color string; supported formats are:
        # - FG
        # - FG_ON_BG
        # - ON_BG
        # - BRIGHT_FG
        # - BRIGHT_FG_ON_BG
        case color_string
        when /^ON_([A-Z]+)$/
          bg = @@colors.index($1.downcase.to_sym)
          return nil if bg.nil?
        when /^(BRIGHT_)?([A-Z]+)(_ON_([A-Z]+))?$/
          bright = !$1.nil?
          fg = @@colors.index($2.downcase.to_sym)
          return nil if fg.nil?
          if $4
            bg = @@colors.index($4.downcase.to_sym)
            return nil if bg.nil?
          end
        else
          return nil
        end

        # Convert the color to an ANSI escape code sequence that sets the current
        # console color.
        color_codes = []
        color_codes << (bright ? @@color_codes[:bright] : @@color_codes[:normal]) unless bright.nil?
        color_codes << (fg + @@fg_color_base).to_s if fg
        color_codes << (bg + @@bg_color_base).to_s if bg
        "\e[#{color_codes.join(';')}m"
      end
    end
  end
end
