namespace :db do
  table_order = [
    :settings,
    :user_statuses,
    :users,
    :user_groups,
    :user_groups_users,
    :permissions,
    :sections,
    :section_entry_statuses,
    :section_entries,
    :comment_statuses,
    :comments,
    :category_groups,
    :categories,
    :category_groups_sections,
    :custom_field_methods,
    :custom_field_types,
    :custom_field_groups,
    :custom_fields,
    :custom_field_values,
    :custom_field_groups_sections,
    :menus,
    :menu_items,
  ]

  desc 'Creates a database independent backup'
  task :export do
    data = {}

    table_order.each do |table|
      data[table] = Zen.database[table].all
    end

    handle = File.open(File.expand_path('../../tmp/backup', __FILE__), 'w')

    handle.write(Marshal.dump(data))
    handle.close
  end

  desc 'Imports a database backup'
  task :import, :backup do |task, args|
    data = Marshal.load(File.open(args[:backup], 'r').read)

    table_order.each do |table|
      Zen.database[table].delete
      Zen.database[table].insert_multiple(data[table])
    end
  end
end
