require 'projects_helper'

module ExtendRarProjectsSetting
  def self.included(base)
    base.send(:include, RarProjectSettingExtension)

    base.class_eval do
      alias_method :project_settings_tabs_without_readme_at_repositories, :project_settings_tabs
      alias_method :project_settings_tabs, :project_settings_tabs_with_readme_at_repositories
    end

  end
end
