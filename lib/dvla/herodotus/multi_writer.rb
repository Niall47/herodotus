module DVLA
  module Herodotus
    class MultiWriter
      attr_reader :targets

      def initialize(*targets, config: nil)
        @targets = *targets
        @config = config
        @file_mutex = Mutex.new
      end

      def write(*args)
        @targets.each do |target|
          if target != $stdout && (@config&.strip_colours_from_files != false)
            stripped_content = args[0].to_s.strip_colour
            if target.respond_to?(:write)
              @file_mutex.synchronize {
                target.write(stripped_content, *args[1..]) 
                target.flush if target.respond_to?(:flush)
              }
            else
              target.write(stripped_content, *args[1..])
            end
          else
            target.write(*args)
            target.flush if target.respond_to?(:flush)
          end
        end
      end

      def close
        @targets.each do |t|
          t.close unless t.eql? $stdout
        end
      end
    end
  end
end
