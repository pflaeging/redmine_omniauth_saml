module Redmine::OmniAuthSAML
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_account_login_top, :partial => 'redmine_omniauth_saml/view_account_login_top'
    render_on :view_my_account_contextual,
		           :partial => 'redmine_omniauth_saml/link_to_account_on_idp'
  end
end
