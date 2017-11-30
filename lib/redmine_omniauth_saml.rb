module Redmine::OmniAuthSAML
  class << self

    def settings_hash
      Setting["plugin_redmine_omniauth_saml"]
    end

    def enabled?
      settings_hash["enabled"]
    end

    def onthefly_creation?
      enabled? && settings_hash["onthefly_creation"]
    end

    def group_support?
      enabled? && settings_hash["group_support"]
    end

    def external_groups?
      enabled? && settings_hash["external_groups"]
    end

    def create_userhome?
      enabled? && settings_hash["create_userhome"]
    end

    def access_role
      settings_hash["access_role"]
    end

    def label_login_with_saml
      settings_hash["label_login_with_saml"]
    end

    def idp_url
      settings_hash["idp_url"]
    end

    def user_attributes_from_saml(omniauth)
      Base.user_attributes_from_saml omniauth
    end

    def group_create_from_saml(user_attributes, user)
      Base.group_create_from_saml(user_attributes, user)
    end

    def configured_saml
      Base.configured_saml
    end

    def on_login_callback
      Base.on_login_callback
    end

  end

  class Base
    class << self
      def saml
        @@saml
      end

      def on_login(&block)
        @@block = block
      end

      def on_login_callback
        @@block ||= nil
      end

      def saml=(val)
        @@saml = HashWithIndifferentAccess.new(val)
      end

      def configured_saml
        raise_configure_exception unless validated_configuration
        saml
      end

      def configure(&block)
        raise_configure_exception if block.nil?
        yield self
        validate_configuration!
      end

      def user_attributes_from_saml(omniauth)
        parameter = Hash.new
        pp = Hash.new
        omniauth.single_value_compatibility = false # we're getting the groups as multivalue from keycloak
        # Rails.logger.info("++ SAML omniauth: " + omniauth.inspect)
        z = Array(omniauth["extra"]["raw_info"]["role"])
        HashWithIndifferentAccess.new.tap do |h|
          required_attribute_mapping.each do |symbol|
            key = configured_saml[:attribute_mapping][symbol]
            keys = key.split('.')
            parameter[symbol] = keys
            pp[symbol] = omniauth[keys[0]][keys[1]].multi(keys[2])
            if pp[symbol] == nil
              pp[symbol] = [""]
            end
            if pp[symbol].length == 1
              pp[symbol] = pp[symbol][0] # convert to string if only one element
            end
            #  Rails.logger.info("\t\t\t" + pp[symbol].inspect)
            # h[symbol] = key.split('.')                # Get an array with nested keys: name.first will return [name, first]
            #   .map {|x| [:[], x]}                     # Create pair elements being :[] symbol and the key
            #   .inject(omniauth) do |hash, params|     # For each key, apply method :[] with key as parameter
            #     hash.send(*params)
            #   end ## do hash
          end ## required_attribute_mapping
        # Rails.logger.info("++ SAML omniauth may return: " + pp.inspect)
        return pp
        end ## HashWithIndifferentAccess
      end ## user_attributes_from_saml

      def group_create_from_saml(user_attributes,user)
        newgroups = user_attributes[:group] # all groups from SAML
        if newgroups.class == String
          newgroups = [newgroups]
        end
        user.groups.where(created_by_omniauth_saml: true).each do |ugroup| # go over all SAML groups
          if newgroups.member?(ugroup.lastname) # is group in workinglist?
            newgroups.delete(ugroup.lastname) # kick group of workinglist
            if not user.is_or_belongs_to?(ugroup) # is user in group
              ugroup.users << user
            end # if user
          else
            ugroup.users.delete(user) # else delete user from group
            if ugroup.users.empty? # Group empty? Then delete
              ugroup.delete
            end
          end # if newgroups
          ugroup.save
        end # do ugroup
        newgroups.each do |realnew| # look for remainder groups
          if realnew != Redmine::OmniAuthSAML.access_role # don't create group for access role
            rng = Group.find_or_create_by(lastname: realnew) # create group
            rng.created_by_omniauth_saml = true
            rng.users << user # join user
            rng.save
          end # if realnew
        end # do realnew
      end # def group_create_from_saml

      private

      def validated_configuration
        @@validated_configuration ||= false
      end

      def required_attribute_mapping
        [ :login,
          :firstname,
          :lastname,
          :mail,
          :group]
      end

      def validate_configuration!
        [ :assertion_consumer_service_url,
          :issuer,
          :idp_sso_target_url,
          :name_identifier_format,
          :idp_slo_target_url,
          :name_identifier_value,
          :attribute_mapping ].each do |k|
            raise "Redmine::OmiauthSAML.configure requires saml.#{k} to be set" unless saml[k]
          end

        raise "Redmine::OmiauthSAML.configure requires either saml.idp_cert_fingerprint or saml.idp_cert to be set" unless saml[:idp_cert_fingerprint] || saml[:idp_cert]

        required_attribute_mapping.each do |k|
          raise "Redmine::OmiauthSAML.configure requires saml.attribute_mapping[#{k}] to be set" unless saml[:attribute_mapping][k]
        end

        raise 'Redmine::OmiauthSAML on_login must be a Proc only' if on_login_callback && !on_login_callback.is_a?(Proc)

        @@validated_configuration = true

        configure_omniauth_saml_middleware
      end

      def raise_configure_exception
        raise 'Redmine::OmniAuthSAML must be configured from an initializer. See README of redmine_omniauth_saml for instructions'
      end

      def configure_omniauth_saml_middleware
        saml_options = configured_saml
        Rails.application.config.middleware.use ::OmniAuth::Builder do
            provider :saml, saml_options
        end
      end
    end
  end
end ## module
