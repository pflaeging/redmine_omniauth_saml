require_dependency 'user'

class User

  def self.group_member?(grouparray)
    user_group_allow = false
    if Redmine::OmniAuthSAML.group_support? == false
      return true
    end
    if grouparray.class == String
      if grouparray == Redmine::OmniAuthSAML.access_role
        return true
      else
        return false
      end
    end
    grouparray.each do |group|
      if group == Redmine::OmniAuthSAML.access_role
        user_group_allow = true
      end
    end
    return user_group_allow
  end

  def self.find_or_create_from_omniauth(omniauth)
    user_attributes = Redmine::OmniAuthSAML.user_attributes_from_saml omniauth
    Rails.logger.info("++++ Redmine.OmniAuthSaml: " + user_attributes.inspect)
    if group_member?(user_attributes[:group]) == false
      return nil
    end
    user = self.find_by_login(user_attributes[:login])
    unless user
      user = EmailAddress.find_by(address: user_attributes[:mail]).try(:user)
      if user.nil? && Redmine::OmniAuthSAML.onthefly_creation?
	       user = User.new(:status => 1, :language => Setting.default_language)
         # user = new user_attributes
	       user.mail = user_attributes[:mail]
	       user.firstname = user_attributes[:firstname]
	       user.lastname = user_attributes[:lastname]
         user.created_by_omniauth_saml = true
         user.login    = user_attributes[:login]
         user.activate
         user.save!
         user.reload

         ####### PP #########
         if Redmine::OmniAuthSAML.create_userhome?
           projectname = "#{user.firstname} #{user.lastname} Home"
           projectid = "#{user.login}_-_home".gsub(/@/,'_').gsub(/\./,'_')
           Rails.logger.info "++ Create Project: #{projectid} with name \"#{projectname}\""
           projectmodules = ["issue_tracking", "wiki", "calendar", "taskboard", "news", "gantt", "time_tracking"]
           begin
             if Project.find(projectid)
               Rails.logger.info "Projectid #{projectid} exists!"
             end
           rescue ActiveRecord::RecordNotFound
             myhomeproject = Project.create(:name => projectname,
                                           :identifier => projectid,
                                           :enabled_module_names => projectmodules
                                          )
          end
          projectrole = Role.find_by_name("Manager")
          Rails.logger.info "++ Role for #{user.id} in #{myhomeproject.id} with role #{projectrole.id}"
          newMember = Member.create_principal_memberships(user,
                                                          :project_id => myhomeproject.id,
                                                          :role_ids => [projectrole.id])
        end
        ####### PP ##########
      end
    end
    # Create groups if wanted:
    if Redmine::OmniAuthSAML.external_groups? and Redmine::OmniAuthSAML.group_support?
      Redmine::OmniAuthSAML.group_create_from_saml(user_attributes,user)
    end
    Redmine::OmniAuthSAML.on_login_callback.call(omniauth, user) if Redmine::OmniAuthSAML.on_login_callback
    user
  end

  def change_password_allowed_with_omniauth_saml?
    change_password_allowed_without_omniauth_saml? && !created_by_omniauth_saml?
  end

  alias_method_chain :change_password_allowed?, :omniauth_saml

end
