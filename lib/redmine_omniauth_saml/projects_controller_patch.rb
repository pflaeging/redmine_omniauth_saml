require_dependency 'projects_controller'

module Redmine::OmniAuthSaml
  module ProjectsControllerPatch
      def self.included(base)
        base.class_eval {
          include InstanceMethods
          alias_method_chain :create, :homedir
        }
      end
  end
  module InstanceMethods
    def create_with_homedir
      Logger.info "++ Inside Create_With_Homedir"
      if /-home$/.match(params[:project]{"identifier"})
        Logger.info "+++ Found wrong project_id"
        flash[:notice] = l(:notice_error_home)
        return
      else
        Logger.info "+++ project_id OK"
        super.create
      end
    end
  end
end

unless ProjectsController.included_modules.include? Redmine::OmniAuthSAML::ProjectsControllerPatch
  ProjectsController.send(:include, Redmine::OmniAuthSAML::ProjectsControllerPatch)
end
