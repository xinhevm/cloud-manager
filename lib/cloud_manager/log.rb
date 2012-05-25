require 'logger'
module Serengeti
  module CloudManager

    LOG_LEVEL = {'debug'=>Logger::DEBUG, 'info'=>Logger::INFO, 'warning'=>Logger::WARN, 'error' => Logger::ERROR,}
    LOG_LEVEL_NAME = LOG_LEVEL.invert

    class SerengetiLogger < Logger
      @@level = LOG_LEVEL['debug']
      def self.log_level= (log_level)
        @@level = LOG_LEVEL[log_level.downcase]
        @@level ||= LOG_LEVEL['debug']
      end

      def initialize(options={})
        @level = options[:level] || @@level || LOG_LEVEL['debug']
        log_file = options[:file] || STDOUT
        @logger = Logger.new(log_file)
        @logger.formatter = proc do |severity, datetime, progname, msg|
          "[#{datetime.rfc2822}] #{severity}: #{msg}\n"
        end
        @logger.level = @level
        puts "initiated logger with level #{LOG_LEVEL_NAME[@level]} and output to #{log_file}"
      end

      def info(msg)
        @logger.info(msg2str(msg))
      end

      def fatal(msg)
        @logger.fatal(msg2str(msg))
      end

      def warn(msg)
        @logger.warn(msg2str(msg))
      end

      def debug(msg)
        @logger.debug(msg2str(msg))
      end

      def error(msg)
        @logger.error(msg2str(msg))
      end

      def inspect; "<Cloud-manager-Logger>" end

      def msg2str(msg)
        case msg
        when ::String
          msg
        when ::Exception
          "EXCEPTION #{ msg.message } (#{ msg.class })\n" <<
          (msg.backtrace || []).join("\n")
        else
          msg.inspect
        end
      end
    end

    class Cloud
      @@self_logger = nil
      def self.Logger
        @@self_logger = SerengetiLogger.new if @@self_logger.nil?
        @@self_logger
      end

      def log_level= (log_level)
        raise "Unknown log level #{log_level}, it should be in #{LOG_LEVEL.keys}" if LOG_LEVEL.has_key?(log_level)
        SerengetiLogger.log_level = LOG_LEVEL[log_level.to_s.downcase]
      end
    end
  end

end