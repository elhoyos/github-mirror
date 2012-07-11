require 'rubygems'
require 'trollop'
require 'daemons'
require 'etc'

# Base class for all GHTorrent command line utilities. Provides basic command
# line argument parsing and command bootstraping support. The order of
# initialization is the following:
# prepare_options
# validate
# go

module GHTorrent
  class Command

    attr_reader :args, :options, :name

    # Specify the run method for subclasses.
    class << self
      def run(args = ARGV)
        command = new(args)
        command.process_options
        command.validate

        if command.options[:daemon]
          if Process.uid == 0
            # Daemonize as a proper system daemon
            Daemons.daemonize(:app_name   => File.basename($0),
                              :dir_mode   => :system,
                              :log_dir    => "/var/log",
                              :backtrace  => true,
                              :log_output => true)
            STDERR.puts "Became a daemon"
            # Change effective user id for the process
            unless command.options[:user].nil?
              Process.euid = Etc.getpwnam(command.options[:user]).uid
            end
          else
            # Daemonize, but output in current directory
            Daemons.daemonize(:app_name   => File.basename($0),
                              :dir_mode   => :normal,
                              :dir        => Dir.getwd,
                              :backtrace  => true,
                              :log_output => true)
          end
        end

        begin
          command.go
        rescue => e
          STDERR.puts e.message
          if command.options.verbose
            STDERR.puts e.backtrace.join("\n")
          else
            STDERR.puts e.backtrace[0]
          end
          exit 1
        end
      end
    end

    def initialize(args)
      @args = args
      @name = self.class.name
    end

    # Specify and parse supported command line options.
    def process_options
      command = self
      @options = Trollop::options(@args) do

        command.prepare_options(self)

        banner <<-END
Standard options:
        END

        opt :config, 'config.yaml file location', :short => 'c',
            :default => 'config.yaml'
        opt :verbose, 'verbose mode', :short => 'v'
        opt :daemon, 'run as daemon', :short => 'd'
        opt :user, 'run as the specified user (only when started as root)',
            :short => 'u', :type => String
      end

      @args = @args.dup
      ARGV.clear
    end

    # Get the version of the project
    def version
      IO.read(File.join(File.dirname(__FILE__), '..', '..', 'VERSION'))
    end

    # This method should be overriden by subclasses in order to specify,
    # using trollop, the supported command line options
    def prepare_options(options)
    end

    # Examine the validity of the provided options in the context of the
    # executed command. Subclasses can also call super to also invoke the checks
    # provided by this class.
    def validate
      if options[:config].nil?
        unless (file_exists?("config.yaml") or file_exists?("/etc/ghtorrent/config.yaml"))
          Trollop::die "No config file in default locations (., /etc/ghtorrent)
                      you need to specify the #{:config} parameter. Read the
                      documentation on how to create a config.yaml file."
        end
      else
        Trollop::die "Cannot find file #{options[:config]}" unless file_exists?(options[:config])
      end

      unless @options[:user].nil?
        if not Process.uid == 0
          Trollop::die "Option --user (-u) cannot be specified by normal users"
        end
          begin
            Etc.getpwnam(@options[:user])
          rescue ArgumentError
            Trollop::die "No such user: #{@options[:user]}"
          end
      end
    end

    # Name of the command that is currently being executed.
    def command_name
      File.basename($0)
    end

    # The actual command code.
    def go
    end

    private

    def file_exists?(file)
      begin
        File::Stat.new(file)
        true
      rescue
        false
      end
    end

  end

end
# vim: set sta sts=2 shiftwidth=2 sw=2 et ai :
