require 'digest/sha1'
class User < ActiveRecord::Base
  validates_presence_of     :login
  validates_presence_of     :dn
  validates_uniqueness_of   :login, :dn, :case_sensitive => false
  before_validation :find_dn

  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  def self.authenticate(login, password)
    u = find_by_login(login) # need to get the salt
    if u.nil?
      u = new
      u.login = login
      u = nil unless u.save
    end
    u && u.authenticated?(password) ? u : nil
  end

  def authenticated?(password)
    return false if ldap_user.nil?
    ldap_user.authenticated?(password)
  end

  def ldap_user
    @ldap_user ||= LdapUser.find(dn)
  end

  def remember_token?
    remember_token_expires_at && Time.now.utc < remember_token_expires_at
  end

  # These create and unset the fields required for remembering users between browser closes
  def remember_me
    self.remember_token_expires_at = 2.weeks.from_now.utc
    self.remember_token            = encrypt("#{email}--#{remember_token_expires_at}")
    save(false)
  end

  def forget_me
    self.remember_token_expires_at = nil
    self.remember_token            = nil
    save(false)
    LdapUser.remove_connection(dn) if dn
    @ldap_user = nil
  end

  private
  def find_dn
    if login.blank?
      self.dn = nil
    else
      begin
        ldap_user = LdapUser.find(login)
        self.dn = ldap_user.dn
      rescue ActiveLdap::EntryNotFound
        self.dn = nil
      end
    end
  end
end
