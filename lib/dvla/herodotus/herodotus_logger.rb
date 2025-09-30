require 'securerandom'

module DVLA
  module Herodotus
    class HerodotusLogger < Logger
      attr_accessor :system_name, :correlation_id, :main, :display_pid, :scenario_id, :prefix_colour

      # Initializes the logger
      # Sets a default correlation_id and creates the formatter
      # Syncs all instances of the HerodotusLogger when the main flag is present
      # Any subsequent loggers will also be synced
      def initialize(system_name, *args, config: DVLA::Herodotus.config, **kwargs)
        super(*args, **kwargs)

        @system_name = system_name
        @main = config.main
        @display_pid = config.display_pid
        @prefix_colour = config.prefix_colour

        @correlation_id = SecureRandom.uuid[0, 8]
        @buffered_logs = []
        set_formatter

        if DVLA::Herodotus.main_logger && @main
          warn("Main logger already set: '#{DVLA::Herodotus.main_logger.system_name}'. This will be overwritten by '#{system_name}'")
        end

        DVLA::Herodotus.main_logger = self if @main
        sync_correlation_ids if DVLA::Herodotus.main_logger
      end

      # Creates a new correlation_id and re-creates the formatter per scenario.
      # If this method is called on an instance of HerodotusLogger not flagged as main
      # the correlation_id of the main logger will be updated and all logger's correlation_ids re-synced.
      def new_scenario(scenario_id)
        @scenario_id = scenario_id
        @correlation_id = SecureRandom.uuid[0, 8]

        if DVLA::Herodotus.main_logger && self != DVLA::Herodotus.main_logger
          warn('You are calling new_scenario on a non-main logger.')

          DVLA::Herodotus.main_logger.correlation_id = @correlation_id
          DVLA::Herodotus.main_logger.scenario_id = @scenario_id
        end

        set_formatter
        sync_correlation_ids if DVLA::Herodotus.main_logger
      end

      # Finds all instances of HerodotusLogger and updates their correlation_id and scenario_id
      # to match that of the main HerodotusLogger.
      def sync_correlation_ids
        ObjectSpace.each_object(DVLA::Herodotus::HerodotusLogger) do |logger|
          unless logger == DVLA::Herodotus.main_logger
            logger.correlation_id = DVLA::Herodotus.main_logger.correlation_id
            logger.scenario_id = DVLA::Herodotus.main_logger.scenario_id
            logger.set_formatter
          end
        end
      end

      %i[debug info warn error fatal].each do |log_level|
        define_method log_level do |progname = nil, buffered: false, &block|
          if buffered
            add_log_to_buffer(log_level, progname, &block)
          else
            set_proc_writer_scenario
            super(progname, &block)
          end
        end
      end

      def release_buffered_logs
        @buffered_logs.each do |log_entry|
          set_proc_writer_scenario
          send(log_entry[:level], log_entry[:progname], &log_entry[:block])
        end
        @buffered_logs.clear
      end

      # Sets the format of the log.
      # Needs to be called each time correlation_id is changed after initialization in-order for the changes to take effect.
      def set_formatter
        self.formatter = proc do |severity, _datetime, _progname, msg|
          now = Time.now
          components = {
            system: @system_name,
            date: now.strftime('%Y-%m-%d'),
            time: now.strftime('%H:%M:%S'),
            correlation: @correlation_id,
            pid: (@display_pid ? Process.pid.to_s : nil),
            level: severity,
            separator: '-- :',
          }

          prefix = colourise_prefix(components)
          "#{prefix}#{msg}\n"
        end
      end

    private

      def add_log_to_buffer(level, progname = nil, &block)
        @buffered_logs << { level: level, progname: progname, block: block }
      end

      def colourise_prefix(components)
        prefix = build_prefix(components)
        return prefix unless @prefix_colour

        case @prefix_colour
        when String, Array
          colourise_text(prefix, @prefix_colour)
        when Hash
          colourise_components(components)
        else
          raise
        end
      end

      def colourise_components(components)
        @prefix_colour.each do |key, colour|
          next unless components[key] && key != :overall

          components[key] = colourise_text(components[key].to_s, colour)
        end

        result = build_prefix(components)
        @prefix_colour[:overall] ? colourise_text(result, @prefix_colour[:overall]) : result
      end

      def colourise_text(text, colour_spec)
        return text unless colour_spec

        methods = colour_spec.is_a?(Array) ? colour_spec : colour_spec.to_s.split('.')
        methods.reduce(text) { |str, method| str.public_send(method) }
      end

      def build_prefix(components)
        bracket_content = [components[:system], components[:date], components[:time], components[:correlation], components[:pid]].compact.join(' ')
        "[#{bracket_content}] #{components[:level]} #{components[:separator]} "
      end

      def set_proc_writer_scenario
        if @logdev.dev.is_a?(DVLA::Herodotus::MultiWriter) && @logdev.dev.targets.any?(DVLA::Herodotus::ProcWriter)
          proc_writers = @logdev.dev.targets.select { |t| t.is_a? DVLA::Herodotus::ProcWriter }
          proc_writers.each do |pr|
            pr.scenario = @scenario_id
          end
        end
      end
    end
  end
end
