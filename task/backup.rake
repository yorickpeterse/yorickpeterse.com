namespace :db do
  desc 'Creates a database independent backup'
  task :export do

    Zen.database.tables.each do |table|
      handle = File.open(
        File.expand_path('../../tmp/%s' % table, __FILE__),
        'w'
      )

      handle.write(Marshal.dump([table, Zen.database[table].all]))
      handle.close
    end
  end

  desc 'Imports a database backup'
  task :import, :backup do |task, args|
    table, rows = Marshal.load(File.open(args[:backup], 'r').read)

    Zen.database[table].delete
    Zen.database[table].insert_multiple(rows)
  end
end
