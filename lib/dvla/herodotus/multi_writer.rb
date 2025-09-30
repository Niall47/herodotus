module DVLA
  module Herodotus
    class MultiWriter
      attr_reader :targets

      def initialize(*targets, config: nil)
        @targets = *targets
        @config = config
      end

      def write(*args)
        @targets.each do |target|
          if target != $stdout && (@config&.strip_colours_from_files != false)
            stripped_content = args[0].to_s.strip_colour
            target.write(stripped_content, *args[1..])
          else
            target.write(*args)
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
