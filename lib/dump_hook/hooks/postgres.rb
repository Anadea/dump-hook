require "dump_hook/hooks/connectable"

module DumpHook
  module Hooks
    class Postgres
      include ::DumpHook::Hooks::Connectable

      def dump(filename)
        args = ['-a', '-x', '-O', '-f', filename, '-Fc', '-T', 'schema_migrations']
        args.concat(['-d', @connection_settings.database])
        args.concat(['-U', @connection_settings.username]) if @connection_settings.username
        args.concat(['-h', @connection_settings.host]) if @connection_settings.host
        args.concat(['-p', @connection_settings.port.to_s]) if @connection_settings.port
        Kernel.system("pg_dump", *args)
      end

      def restore(filename)
        args = ['-d', @connection_settings.database]
        args.concat(['-U', @connection_settings.username]) if @connection_settings.username
        args.concat(['-h', @connection_settings.host]) if @connection_settings.host
        args.concat(['-p', @connection_settings.port.to_s]) if @connection_settings.port
        args << filename
        Kernel.system("pg_restore", *args)
      end
    end
  end
end
