module DumpHook
  module Hooks
    module Connectable
      def initialize(connection_settings)
        @connection_settings = connection_settings
      end
    end
  end
end
