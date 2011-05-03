namespace :db do
  
  desc 'Dumps the content of all tables (except the user related tables)'
  task :dump do
    Zen::Database.handle.tables.each do |table|
      # Skip migration tables
      if table.to_s.include?('migrations_')
        next
      end

      rows = Zen::Database.handle[table.to_sym].all
      dump = __DIR__("../dump/#{table}")

      File.open(dump, 'w') do |handle|
        handle.write(Marshal.dump(rows)) 
        handle.close
      end
    end
  end

  desc 'Inserts all dumped records into the database if they don\'t exist yet.'
  task :restore, :table do |task, args|
    if !args[:table]
      abort "You need to specify a table to restore"
    end

    dump = __DIR__("../dump/#{args[:table]}")

    if !File.exist?(dump)
      abort "There is no table dump for the table \"#{args[:table]}\""
    end

    dump = File.read(dump, File.size(dump)).to_s
    dump = Marshal.load(dump)

    # Only insert the row if the primary value isn't there
    dump.each do |row|
      if !Zen::Database.handle[args[:table].to_sym].filter(:id => row[:id])
        Zen::Database.handle[args[:table].to_sym].insert(row)
      end
    end
  end

end
