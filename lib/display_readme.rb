class DisplayReadme < Redmine::Hook::ViewListener

  @@markdown_ext = %w(.markdown .mdown .mkdn .md .mkd .mdwn .mdtxt .mdtext .text)

  def view_repositories_show_contextual(context)

    return if EnabledModule.where(:project_id => context[:project].id, :name => 'readme_at_repository').empty? ||
      RarProjectSetting.find_by(project_id: context[:project].id).nil?

    path = context[:request].params['path'] || ''
    rev = (_rev = context[:request].params['rev']).blank? ? nil : _rev
    repo_id = context[:request].params['repository_id']

    blk = repo_id ? lambda { |r| r.identifier == repo_id } : lambda { |r| r.is_default }
    repo = context[:project].repositories.find &blk

    entry = repo.entry(path)
    if not entry.is_dir?
      return ''
    end

    unless file = (repo.entries(path, rev) || []).find { |entry| entry.name =~ /!?README((\.).*)?/i }
      return ''
    end

    unless raw_readme_text = repo.cat(file.path, rev)
      return ''
    end

    # Force encoding to UTF-8 to prevent ASCII-8BIT/UTF-8 compatibility errors
    raw_readme_text = raw_readme_text.force_encoding('UTF-8')

    formatter_name = ''
    if @@markdown_ext.include?(File.extname(file.path))
      # Try to find available Markdown formatter in Redmine 6.0
      available_formats = Redmine::WikiFormatting.format_names
      formatter_name = available_formats.find { |name| name =~ /markdown/i } ||
                      available_formats.find { |name| name.downcase.include?('markdown') }
      
      # In Redmine 6.0, try common markdown formatter names
      unless formatter_name
        ['markdown', 'common_mark', 'redcarpet'].each do |name|
          begin
            if Redmine::WikiFormatting.formatter_for(name)
              formatter_name = name
              break
            end
          rescue
            next
          end
        end
      end
    end

    # Use default formatter (textile) if no markdown formatter found
    formatter_name ||= ''
    
    begin
      formatter = Redmine::WikiFormatting.formatter_for(formatter_name).new(raw_readme_text)
    rescue => e
      # Fallback to default formatter if there's any error
      formatter = Redmine::WikiFormatting.formatter_for('').new(raw_readme_text)
    end

    rar_setting = RarProjectSetting.find_by(project_id: context[:project].id)

    context[:controller].send(:render_to_string, {
      :partial => 'repository/readme',
      :locals => {:html => formatter.to_html, position: rar_setting[:position], show: rar_setting[:show] }
    })
  end
end
