require "dump_hook/hooks/connectable"

module DumpHook
  module Hooks
    class MySql
      include ::DumpHook::Hooks::Connectable

      def dump(filename)
        args = [@connection_settings.database]
        args << "--compress"
        args.concat(["--result-file", filename])
        args.concat(["--ignore-table", "#{@connection_settings.database}.schema_migrations"])
        args.concat ['--user', @connection_settings.username] if @connection_settings.username
        args << "--password=#{@connection_settings.password}" if @connection_settings.password
        Kernel.system("mysqldump", *args)
      end

      def restore(filename)
        args = [@connection_settings.database]
        args.concat ["-e", "source #{filename}"]
        args.concat ['--user', @connection_settings.username] if @connection_settings.username
        args << "--password=#{@connection_settings.password}" if @connection_settings.password
        Kernel.system("mysql", *args)
      end
    end
  end
end
