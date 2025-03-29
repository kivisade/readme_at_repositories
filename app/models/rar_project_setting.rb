class RarProjectSetting < ActiveRecord::Base
  if defined?(ProtectedAttributes) || ::ActiveRecord::VERSION::MAJOR < 4
    attr_accessible :project_id, :position, :show
  end
end
