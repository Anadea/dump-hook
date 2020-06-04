require 'spec_helper'
require 'sequel'

describe DumpHook do
  it 'has a version number' do
    expect(DumpHook::VERSION).not_to be nil
  end

  describe '.setup' do
    context 'default settings' do
      before(:each) do
        DumpHook.setup do |_|
        end
      end

      it 'sets dumps_location' do
        expect(DumpHook.settings.dumps_location).to eq('tmp/dump_hook')
      end

      it 'sets remove_old_dumps' do
        expect(DumpHook.settings.remove_old_dumps).to eq(true)
      end

      it 'does not set actual' do
        expect(DumpHook.settings.actual).to be nil
      end
    end

    context 'custom settings' do
      let(:new_location) { 'new_location' }
      let(:new_remove_old_dumps) { false }
      let(:new_database) { 'new_database' }
      let(:new_username) { 'new_username' }
      let(:new_host) { 'example.com' }
      let(:new_port) { 600 }
      let(:new_actual) { 'actual_with_some_phrase' }

      it 'sets dumps_location' do
        DumpHook.setup { |c| c.dumps_location = new_location }
        expect(DumpHook.settings.dumps_location).to eq(new_location)
      end

      it 'sets remove_old_dumps' do
        DumpHook.setup { |c| c.remove_old_dumps = new_remove_old_dumps }
        expect(DumpHook.settings.remove_old_dumps).to eq(new_remove_old_dumps)
      end

      it 'sets database' do
        DumpHook.setup { |c| c.database = new_database }
        expect(DumpHook.settings.database).to eq(new_database)
      end

      it 'sets username' do
        DumpHook.setup { |c| c.username = new_username }
        expect(DumpHook.settings.username).to eq(new_username)
      end

      it 'sets host' do
        DumpHook.setup { |c| c.host = new_host }
        expect(DumpHook.settings.host).to eq(new_host)
      end

      it 'sets port' do
        DumpHook.setup { |c| c.port = new_port }
        expect(DumpHook.settings.port).to eq(new_port)
      end

      it 'sets actual' do
        DumpHook.setup { |c| c.actual = new_actual }
        expect(DumpHook.settings.actual).to eq(new_actual)
      end
    end
  end

  describe '.execute_with_dump' do
    let(:object) { Object.new }

    before(:each) do
      object.extend(DumpHook)
    end

    context 'folders creation' do
      let(:dumps_location) { "tmp1/tmp2/tmp3" }

      before(:each) do
        DumpHook.setup do |c|
          c.dumps_location = dumps_location
        end
      end

      after(:each) do
        FileUtils.rm_r('tmp1')
      end

      it 'creates folders' do
        object.execute_with_dump("some_dump") { }
        expect(Dir.exist?(dumps_location)).to be(true)
      end
    end

    shared_context "mysql db init" do
      let(:mysql_db_name) { 'dump_hook_test' }
      let(:mysql_username) { 'root' }
      let(:mysql_db) { Sequel.connect(adapter: 'mysql2', user: mysql_username) }

      before(:each) do
        mysql_db.run("CREATE DATABASE #{mysql_db_name}")
        mysql_db.run("USE #{mysql_db_name}")
      end

      after(:each) do
        mysql_db.run("DROP DATABASE #{mysql_db_name}")

        mysql_db.disconnect
      end
    end

    shared_context "postgres db init" do
      let(:postgres_db_name) { 'dump_hook_test' }
      let(:postgres_db) { Sequel.connect(adapter: 'postgres', database: postgres_db_name) }

      before(:each) do
        Kernel.system('createdb', postgres_db_name)
      end

      after(:each) do
        postgres_db.disconnect
        Kernel.system("dropdb", postgres_db_name)
      end
    end

    shared_examples_for 'data insertion and restoring' do
      before(:each) do
        object.execute_with_dump("some_dump") do
          db.run("create table t (a text, b text)")
          db.run("insert into t values ('a', 'b')")
        end
      end

      it 'inserts some info' do
        expect(db[:t].map([:a, :b])).to eq([['a', 'b']])
      end

      it 'uses dump content if dump exists' do
        db.run("delete from t")
        expect { object.execute_with_dump("some_dump") { } }.to change { db[:t].map([:a, :b]) }.to([['a', 'b']])
      end
    end

    context 'postgres' do
      include_context "postgres db init"
      let(:db) { postgres_db }

      before(:each) do
        DumpHook.setup do |c|
          c.database = postgres_db_name
        end
      end

      after(:each) do
        FileUtils.rm_r('tmp')
      end

      it 'creates dump file' do
        object.execute_with_dump("some_dump") { }
        expect(File.exist?("tmp/dump_hook/some_dump.dump")).to be(true)
      end

      it_behaves_like "data insertion and restoring" do
        let(:db) { postgres_db }
      end
    end

    context 'mysql' do
      include_context "mysql db init"

      before(:each) do
        DumpHook.setup do |c|
          c.database = mysql_db_name
          c.database_type = 'mysql'
          c.username = mysql_username
        end
      end

      after(:each) do
        FileUtils.rm_r('tmp')
      end

      it 'creates dump file' do
        object.execute_with_dump("some_dump") { }
        expect(File.exists?("tmp/dump_hook/some_dump.dump")).to be(true)
      end

      it_behaves_like "data insertion and restoring" do
        let(:db) { mysql_db }
      end
    end

    context "multi DBs" do
      include_context "postgres db init"
      include_context "mysql db init"

      before(:each) do
        FileUtils.mkdir_p("tmp")

        DumpHook.setup do |c|
          c.sources = { primary: { type: :postgres, database: postgres_db_name },
                        secondary: { type: :mysql, username: mysql_username, database: mysql_db_name } }
        end
      end

      after(:each) do
        FileUtils.rm_r('tmp')
      end

      it "creates dump files" do
        object.execute_with_dump("some_dump") { }
        expect(File.exist?("tmp/dump_hook/some_dump/primary.dump")).to be(true)
        expect(File.exist?("tmp/dump_hook/some_dump/secondary.dump")).to be(true)
      end

      it_behaves_like "data insertion and restoring" do
        let(:db) { mysql_db }
      end

      it_behaves_like "data insertion and restoring" do
        let(:db) { postgres_db }
      end
    end
  end
end
