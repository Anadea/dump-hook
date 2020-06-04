require "dump_hook/version"
require "dump_hook/hooks/mysql"
require "dump_hook/hooks/postgres"
require "timecop"
require "ostruct"

module DumpHook
  class Settings
    attr_accessor :database,
                  :dumps_location,
                  :remove_old_dumps,
                  :actual,
                  :database_type,
                  :username,
                  :password,
                  :host,
                  :port,
                  :sources,
                  :with_sources

    def initialize
      @database_type = 'postgres'
      @dumps_location = 'tmp/dump_hook'
      @remove_old_dumps = true
      @with_sources = false
      @sources = {}
    end
  end

  class << self
    attr_accessor :settings
    attr_accessor :hooks

    def setup
      self.settings = Settings.new
      yield(settings)
      unless settings.sources.empty?
        settings.with_sources = true
      end
      unless settings.database.nil?
        single_source = { type: settings.database_type.to_sym,
                          database: settings.database,
                          username: settings.username,
                          password: settings.password,
                          host: settings.host,
                          port: settings.port }
        self.settings.sources[settings.database_type.to_sym] = single_source
      end
    end
  end

  def execute_with_dump(name, opts={}, &block)
    created_on = opts[:created_on]
    actual = opts[:actual] || settings.actual
    create_dirs_if_not_exists
    filename = full_filename(name, created_on, actual)
    if File.exist?(filename)
      restore_dump(filename)
    else
      if created_on
        Timecop.travel(created_on)
      elsif actual && settings.remove_old_dumps
        FileUtils.rm(Dir.glob(full_filename(name, nil, "*")))
      end
      block.call
      Timecop.return
      store_dump(filename)
    end
  end

  def settings
    DumpHook.settings
  end

  def store_dump(filename)
    FileUtils.mkdir_p(filename)
    settings.sources.each do |name, parameters|
      filename_with_namespace = File.join(filename, "#{name}.dump")
      connection_settings = OpenStruct.new(parameters.slice(:database, :username, :password, :port, :host))
      dumper = case parameters[:type]
               when :postgres
                 Hooks::Postgres.new(connection_settings)
               when :mysql
                 Hooks::MySql.new(connection_settings)
               end
      dumper.dump(filename_with_namespace)
    end
  end

  def restore_dump(filename)
    FileUtils.mkdir_p(filename)
    settings.sources.each do |name, parameters|
      filename_with_namespace = File.join(filename, "#{name}.dump")
      connection_settings = OpenStruct.new(parameters.slice(:database, :username, :password, :port, :host))
      dumper = case parameters[:type]
               when :postgres
                 Hooks::Postgres.new(connection_settings)
               when :mysql
                 Hooks::MySql.new(connection_settings)
               end
      dumper.restore(filename_with_namespace)
    end
  end

  def full_filename(name, created_on, actual)
    name_with_created_on = name
    if created_on
      name_with_created_on = "#{name_with_created_on}_#{created_on.to_s(:number)}"
    elsif actual
      name_with_created_on = "#{name_with_created_on}_actual#{actual}"
    end
    full_path = "#{settings.dumps_location}/#{name_with_created_on}"

    settings.with_sources ? full_path : "#{full_path}.dump"
  end

  def create_dirs_if_not_exists
    FileUtils.mkdir_p(settings.dumps_location)
  end
end
