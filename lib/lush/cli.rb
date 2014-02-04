#
# Copyright (c) 2014 by Lifted Studios. All Rights Reserved.
#

require 'shellwords'

module Lush
  # Handles the command-line interface of the shell.
  class CLI
    # List of built in commands and their implementation.
    BUILTINS = {
      'cd' => -> (dir) { Dir.chdir(dir) },
      'exit' => -> (code = 0) { exit(code.to_i) },
      'export' => lambda do |args|
        key, value = args.split('=')
        ENV[key] = value
      end
    }

    # Creates a new instance of the `CLI` class.
    def initialize
      init_prompt
    end

    # Starts the shell.
    def run
      loop do
        print_prompt
        line = get_command_line
        commands = split_on_pipes(line)

        streams = Streams.new

        commands.each_with_index do |command, index|
          program, *arguments = Shellwords.shellsplit(command)

          if builtin?(program)
            call_builtin(program, *arguments)
          else
            streams.next(pipe: index + 1 < commands.size)
            spawn_program(program, *arguments, streams)
            streams.close
          end
        end

        Process.waitall
      end
    end

    private

    # Determines if `program` is a built-in command.
    #
    # @param [String] program Name of the program to execute.
    # @return [Boolean] Flag indicating whether `program` is a built-in command.
    def builtin?(program)
      BUILTINS.key?(program)
    end

    # Executes a built-in command.
    #
    # @param [String] program Name of the program to execute.
    # @param [Array<String>] arguments Arguments for the program.
    def call_builtin(program, *arguments)
      BUILTINS[program].call(*arguments)
    end

    # Gets the command line from the user.
    #
    # @return [String] Command-line text to execute.
    def get_command_line
      $stdin.gets.strip
    end

    # Initializes the command-line prompt string.
    def init_prompt
      ENV['PROMPT'] = '-> '
    end

    # Displays the prompt.
    def print_prompt
      $stdout.print(ENV['PROMPT'])
    end

    # Executes the given program in a sub-process.
    #
    # @param [String] program Name of the program to execute.
    # @param [Array<String>] arguments Arguments to supply to the program.
    # @param [Streams] streams Set of streams to use for input and output.
    def spawn_program(program, *arguments, streams)
      fork do
        streams.reopen_out
        streams.reopen_in

        exec program, *arguments
      end
    end

    # Splits a command line on pipe delimiters.
    #
    # @param [String] line Command line text.
    # @return [Array<String>] List of pipeline components.
    def split_on_pipes(line)
      line.scan(/([^"'|]+)|["']([^"']+)["']/).flatten.compact
    end
  end
end