# -*- coding: utf-8 -*-

require 'al-test-utils'

class TestBase < Test::Unit::TestCase
  include AlTestUtils

  priority :must
  def test_to_ldif
    make_temporary_group do |group,|
      assert_to_ldif(group)

      group.gidNumber += 1
      group.description = ["Description", {"en" => "Description(en)"}]
      assert_to_ldif(group)
    end
  end

  priority :normal
  def test_save_with_changes
    make_temporary_user do |user, password|
      user.cn += "!!!"
      assert_true(detect_modify(user) {user.save})
    end
  end

  def test_save_without_changes
    make_temporary_user do |user, password|
      assert_false(detect_modify(user) {user.save})
    end
  end

  def test_normalize_dn_attribute
    make_ou("Ous")
    ou_class = Class.new(ActiveLdap::Base)
    ou_class.ldap_mapping(:dn_attribute => "OU",
                          :prefix => "ou=OUS",
                          :classes => ["top", "organizationalUnit"])
    ou_class.new("ou1").save!
    ou_class.new("ou2").save!

    ou1 = ou_class.find("ou1")
    assert_equal("ou1", ou1.ou)
    assert_equal("ou=ou1,#{ou_class.base}", ou1.dn)
    ou2 = ou_class.find("ou2")
    assert_equal("ou2", ou2.ou)
    assert_equal("ou=ou2,#{ou_class.base}", ou2.dn)
  end

  def test_excluded_classes
    mapping = {:classes => ["person"]}
    person_class = Class.new(@user_class)
    person_class.ldap_mapping(mapping)

    no_organizational_person_class = Class.new(@user_class)
    no_organizational_person_mapping =
      mapping.merge(:excluded_classes => ["organizationalPerson"])
    no_organizational_person_class.ldap_mapping(no_organizational_person_mapping)

    no_simple_person_class = Class.new(@user_class)
    no_simple_person_mapping =
      mapping.merge(:excluded_classes => ['shadowAccount', 'inetOrgPerson',
                                          "organizationalPerson"])
    no_simple_person_class.ldap_mapping(no_simple_person_mapping)

    make_temporary_user do |user1,|
      make_temporary_user(:simple => true) do |user2,|
        assert_equal([user1.dn, user2.dn].sort,
                     person_class.find(:all).collect(&:dn).sort)

        no_organizational_people = no_organizational_person_class.find(:all)
        assert_equal([user2.dn].sort,
                     no_organizational_people.collect(&:dn).sort)

        assert_equal([user2.dn].sort,
                     no_simple_person_class.find(:all).collect(&:dn).sort)
      end
    end
  end

  def test_new_with_dn
    cn = "XXX"
    dn = "cn=#{cn},#{@user_class.base}"
    user = @user_class.new(ActiveLdap::DN.parse(dn))
    assert_equal(cn, user.cn)
    assert_equal(dn, user.dn)
  end

  def test_dn_attribute_per_instance_with_invalid_value
    user = @user_class.new
    assert_equal("uid", user.dn_attribute)

    user.dn = nil
    assert_equal("uid", user.dn_attribute)
    assert_nil(user.uid)

    user.dn = ""
    assert_equal("uid", user.dn_attribute)
    assert_nil(user.uid)
  end

  def test_dn_attribute_per_instance
    user = @user_class.new
    assert_equal("uid", user.dn_attribute)
    assert_nil(user.uid)

    user.dn = "cn=xxx"
    assert_equal("cn", user.dn_attribute)
    assert_nil(user.uid)
    assert_equal("xxx", user.cn)
    assert_equal("cn=xxx,#{@user_class.base}", user.dn)

    assert_equal("uid", @user_class.new.dn_attribute)

    user.dn = "ZZZ"
    assert_equal("cn", user.dn_attribute)
    assert_nil(user.uid)
    assert_equal("ZZZ", user.cn)
    assert_equal("cn=ZZZ,#{@user_class.base}", user.dn)

    user.dn = "uid=aaa"
    assert_equal("uid", user.dn_attribute)
    assert_equal("aaa", user.uid)
    assert_equal("ZZZ", user.cn)
    assert_equal("uid=aaa,#{@user_class.base}", user.dn)
  end

  def test_case_insensitive_nested_ou
    ou_class("ou=Users").new("Sub").save!
    make_temporary_user(:uid => "test-user,ou=SUB") do |user, password|
      sub_user_class = Class.new(@user_class)
      sub_user_class.ldap_mapping :prefix => "ou=sub"
      assert_equal("uid=test-user,ou=sub,#{@user_class.base}",
                   sub_user_class.find(user.uid).dn)
    end
  end

  def test_nested_ou
    make_ou("units")
    units = ou_class("ou=units")
    units.new("one").save!
    units.new("two").save!
    units.new("three").save!

    ous = units.find(:all, :scope => :sub).collect {|unit| unit.ou}
    assert_equal(["one", "two", "three", "units"].sort,  ous.sort)

    ous = units.find(:all, :scope => :base).collect {|unit| unit.ou}
    assert_equal(["units"].sort, ous.sort)

    ous = units.find(:all, :scope => :one).collect {|unit| unit.ou}
    assert_equal(["one", "two", "three"].sort, ous.sort)
  end

  def test_initialize_with_recommended_classes
    mapping = {
      :dn_attribute => "cn",
      :prefix => "",
      :scope => :one,
      :classes => ["person"],
    }
    person_class = Class.new(ActiveLdap::Base)
    person_class.ldap_mapping mapping

    person_with_uid_class = Class.new(ActiveLdap::Base)
    person_with_uid_mapping =
      mapping.merge(:recommended_classes => ["uidObject"])
    person_with_uid_class.ldap_mapping person_with_uid_mapping

    name = "sample"
    name_with_uid = "sample-with-uid"
    uid = "1000"

    person = person_class.new(name)
    person.sn = name
    assert(person.save)
    assert_equal([name, name], [person.cn, person.sn])

    person_with_uid = person_with_uid_class.new(name_with_uid)
    person_with_uid.sn = name_with_uid
    assert(!person_with_uid.save)
    person_with_uid.uid = uid
    assert(person_with_uid.save)
    assert_equal([name_with_uid, name_with_uid],
                 [person_with_uid.cn, person_with_uid.sn])
    assert_equal(uid, person_with_uid.uid)

    assert_equal([person.dn, person_with_uid.dn],
                 person_class.search.collect {|dn, attrs| dn})
    person_class.required_classes += ["uidObject"]
    assert_equal([person_with_uid.dn],
                 person_class.search.collect {|dn, attrs| dn})

    assert_equal([person.dn, person_with_uid.dn],
                 person_with_uid_class.search.collect {|dn, attrs| dn})
  end

  def test_search_with_object_class
    ou_class = Class.new(ActiveLdap::Base)
    ou_class.ldap_mapping :dn_attribute => "ou",
                          :prefix => "",
                          :scope => :one,
                          :classes => ["organizationalUnit"]

    name = "sample"
    ou = ou_class.new(name)
    assert(ou.save)
    assert_equal(name, ou.ou)

    assert_equal([ou.dn],
                 ou_class.search(:value => name).collect {|dn, attrs| dn})
    ou_class.required_classes += ["organization"]
    assert_equal([],
                 ou_class.search(:value => name).collect {|dn, attrs| dn})
  end

  def test_search_with_attributes_without_object_class
    make_temporary_user do |user, password|
      entries = @user_class.search(:filter => "#{user.dn_attribute}=#{user.id}",
                                   :attributes => ["uidNumber"])
      assert_equal([[user.dn, {"uidNumber" => [user.uid_number.to_s]}]],
                    entries)
    end
  end

  def test_new_without_argument
    user = @user_class.new
    assert_equal(@user_class_classes, user.classes)
    assert(user.respond_to?(:cn))
  end

  def test_new_with_invalid_argument
    user = @user_class.new
    assert_raises(ArgumentError) do
      @user_class.new(100)
    end
  end

  def test_loose_dn
    make_temporary_user do |user,|
      assert(user.class.exists?(user.dn))
      assert(user.class.exists?(user.dn.gsub(/,/, " , ")))
      assert(user.class.exists?(user.dn.gsub(/=/, " = ")))
    end
  end

  def test_new_without_class
    no_class_class = Class.new(ActiveLdap::Base)
    no_class_class.ldap_mapping :dn_attribute => "dc", :prefix => "",
                                :classes => []
    assert_raises(ActiveLdap::UnknownAttribute) do
      no_class_class.new("xxx")
    end
  end

  def test_save_for_dNSDomain
    domain_class = Class.new(ActiveLdap::Base)
    domain_class.ldap_mapping :dn_attribute => "dc", :prefix => "",
                              :classes => ['top', 'dcObject', 'dNSDomain']
    name = "ftp"
    a_record = "192.168.1.1"

    domain = domain_class.new('ftp')
    domain.a_record = a_record
    assert(domain.save)
    assert_equal(a_record, domain.a_record)
    assert_equal(a_record, domain_class.find(name).a_record)
  ensure
    domain_class.delete(name) if domain_class.exists?(name)
  end

  def test_dn_by_index_getter
    make_temporary_user do |user,|
      assert_equal(user.dn, user["dn"])
    end
  end

  def test_create_multiple
    ensure_delete_user("temp-user1") do |uid1,|
      ensure_delete_user("temp-user2") do |uid2,|
        attributes = {
          :uid => uid2,
          :sn => uid2,
          :cn => uid2,
          :uid_number => "1000",
          :gid_number => "1000",
          :home_directory => "/home/#{uid2}",
        }

        user1, user2 = @user_class.create([{:uid => uid1}, attributes])
        assert(!user1.errors.empty?)
        assert(!@user_class.exists?(uid1))

        assert_equal([], user2.errors.to_a)
        assert(@user_class.exists?(uid2))
        attributes.each do |key, value|
          value = value.to_i if [:uid_number, :gid_number].include?(key)
          assert_equal(value, user2[key])
        end
      end
    end
  end

  def test_create
    ensure_delete_user("temp-user") do |uid,|
      user = @user_class.create(:uid => uid)
      assert(!user.errors.empty?)
      assert(!@user_class.exists?(uid))

      attributes = {
        :uid => uid,
        :sn => uid,
        :cn => uid,
        :uid_number => "1000",
        :gid_number => "1000",
        :home_directory => "/home/#{uid}",
      }
      user = @user_class.create(attributes)
      assert_equal([], user.errors.to_a)
      assert(@user_class.exists?(uid))
      attributes.each do |key, value|
        value = value.to_i if [:uid_number, :gid_number].include?(key)
        assert_equal(value, user[key])
      end
    end
  end

  def test_reload_of_not_exists_entry
    make_temporary_user do |user,|
      assert_nothing_raised do
        user.reload
      end

      user.destroy

      assert_raises(ActiveLdap::EntryNotFound) do
        user.reload
      end
    end
  end

  def test_reload_and_new_entry
    make_temporary_user do |user1,|
      user2 = @user_class.new(user1.uid)
      assert_equal(user1.attributes["uid"], user2.attributes["uid"])
      assert_not_equal(user1.attributes["objectClass"],
                       @user_class.required_classes)
      assert_equal(@user_class.required_classes,
                   user2.attributes["objectClass"])
      assert_not_equal(user1.attributes["objectClass"],
                       user2.attributes["objectClass"])
      assert(user2.exists?)
      assert(user2.new_entry?)

      user2.reload
      assert(user2.exists?)
      assert(!user2.new_entry?)
      assert_equal(user1.attributes, user2.attributes)
    end
  end

  def test_exists_for_instance
    make_temporary_user do |user,|
      assert(user.exists?)
      assert(!user.new_entry?)

      new_user = @user_class.new(user.uid)
      assert(new_user.exists?)
      assert(new_user.new_entry?)

      user.destroy
      assert(!user.exists?)
      assert(user.new_entry?)

      assert(!new_user.exists?)
      assert(new_user.new_entry?)
    end
  end

  def test_exists_without_required_object_class
    make_temporary_user do |user,|
      @user_class.required_classes -= ["posixAccount"]
      user.remove_class("posixAccount")
      assert(user.save)

      assert(@user_class.exists?(user.dn))
      @user_class.required_classes += ["posixAccount"]
      assert(!@user_class.exists?(user.dn))
      assert_raises(ActiveLdap::EntryNotFound) do
        @user_class.find(user.dn)
      end
    end
  end

  def test_find_dns_without_required_object_class
    make_temporary_user do |user1,|
      make_temporary_user do |user2,|
        make_temporary_user do |user3,|
          @user_class.required_classes -= ["posixAccount"]
          user1.remove_class("posixAccount")
          assert(user1.save)

          @user_class.required_classes += ["posixAccount"]
          assert_raises(ActiveLdap::EntryNotFound) do
            @user_class.find(user1.dn, user2.dn, user3.dn)
          end
          assert_equal([user2.dn, user3.dn],
                       @user_class.find(user2.dn, user3.dn).collect {|u| u.dn})
        end
      end
    end
  end

  def test_reload
    make_temporary_user do |user1,|
      user2 = @user_class.find(user1.uid)
      assert_equal(user1.attributes, user2.attributes)

      user1.cn = "new #{user1.cn}"
      assert_not_equal(user1.attributes, user2.attributes)
      assert_equal(user1.attributes.reject {|k, v| k == "cn"},
                   user2.attributes.reject {|k, v| k == "cn"})

      user2.reload
      assert_not_equal(user1.attributes, user2.attributes)
      assert_equal(user1.attributes.reject {|k, v| k == "cn"},
                   user2.attributes.reject {|k, v| k == "cn"})

      assert(user1.save)
      assert_not_equal(user1.attributes, user2.attributes)
      assert_equal(user1.attributes.reject {|k, v| k == "cn"},
                   user2.attributes.reject {|k, v| k == "cn"})

      user2.reload
      assert_equal(user1.cn, user2.cn)
      assert_equal(user1.attributes.reject {|k, v| k == "cn"},
                   user2.attributes.reject {|k, v| k == "cn"})
    end
  end

  def test_delete
    make_temporary_user do |user1,|
      make_temporary_user do |user2,|
        make_temporary_user do |user3,|
          assert(@user_class.exists?(user1.uid))
          @user_class.delete(user1.dn)
          assert(!@user_class.exists?(user1.uid))

          assert(@user_class.exists?(user2.dn))
          @user_class.delete(user2.uid)
          assert(!@user_class.exists?(user2.dn))

          assert(@user_class.exists?(user3.dn))
          @user_class.delete("uid=#{user3.uid}")
          assert(!@user_class.exists?(user3.dn))
        end
      end
    end

    make_temporary_user do |user1,|
      make_temporary_user do |user2,|
        make_temporary_user do |user3,|
          assert(@user_class.exists?(user1.uid))
          assert(@user_class.exists?(user2.uid))
          assert(@user_class.exists?(user3.uid))
          @user_class.delete([user1.dn, user2.uid, "uid=#{user3.uid}"])
          assert(!@user_class.exists?(user1.uid))
          assert(!@user_class.exists?(user2.uid))
          assert(!@user_class.exists?(user3.uid))
        end
      end
    end
  end

  def test_inherit_base
    sub_user_class = Class.new(@user_class)
    sub_user_class.ldap_mapping :prefix => "ou=Sub"
    assert_equal("ou=Sub,#{@user_class.base}", sub_user_class.base)
    sub_user_class.send(:include, Module.new)
    assert_equal("ou=Sub,#{@user_class.base}", sub_user_class.base)

    sub_sub_user_class = Class.new(sub_user_class)
    sub_sub_user_class.ldap_mapping :prefix => "ou=SubSub"
    assert_equal("ou=SubSub,#{sub_user_class.base}", sub_sub_user_class.base)
    sub_sub_user_class.send(:include, Module.new)
    assert_equal("ou=SubSub,#{sub_user_class.base}", sub_sub_user_class.base)
  end

  def test_compare
    make_temporary_user do |user1,|
      make_temporary_user do |user2,|
        make_temporary_user do |user3,|
          make_temporary_user do |user4,|
            actual = ([user1, user2, user3] & [user1, user4])
            assert_equal([user1].collect {|user| user.id},
                         actual.collect {|user| user.id})
          end
        end
      end
    end
  end

  def test_ldap_mapping_symbol_dn_attribute
    ou_class = Class.new(ActiveLdap::Base)
    ou_class.ldap_mapping(:dn_attribute => :ou,
                          :prefix => "",
                          :classes => ["top", "organizationalUnit"])
    assert_equal(["ou=Groups,#{current_configuration['base']}",
                  "ou=Users,#{current_configuration['base']}"],
                 ou_class.find(:all).collect(&:dn).sort)
  end

  def test_ldap_mapping_validation
    ou_class = Class.new(ActiveLdap::Base)
    assert_raises(ArgumentError) do
      ou_class.ldap_mapping :dnattr => "ou"
    end

    assert_nothing_raised do
      ou_class.ldap_mapping :dn_attribute => "ou",
                            :prefix => "",
                            :classes => ["top", "organizationalUnit"]
    end
  end

  def test_to_xml
    ou = ou_class.new("Sample")
    assert_equal(<<-EOX, ou.to_xml(:root => "ou"))
<ou>
  <dn>#{ou.dn}</dn>
  <objectClass>organizationalUnit</objectClass>
  <objectClass>top</objectClass>
  <ou>Sample</ou>
</ou>
EOX

    assert_equal(<<-EOX, ou.to_xml)
<>
  <dn>#{ou.dn}</dn>
  <objectClass>organizationalUnit</objectClass>
  <objectClass>top</objectClass>
  <ou>Sample</ou>
</>
EOX

    make_temporary_user do |user, password|
    assert_equal(<<-EOX, user.to_xml(:root => "user"))
<user>
  <dn>#{user.dn}</dn>
  <cn>#{user.cn}</cn>
  <gidNumber>#{user.gid_number}</gidNumber>
  <homeDirectory>#{user.home_directory}</homeDirectory>
  <jpegPhoto>#{jpeg_photo}</jpegPhoto>
  <objectClass>inetOrgPerson</objectClass>
  <objectClass>organizationalPerson</objectClass>
  <objectClass>person</objectClass>
  <objectClass>posixAccount</objectClass>
  <objectClass>shadowAccount</objectClass>
  <sn>#{user.sn}</sn>
  <uid>#{user.uid}</uid>
  <uidNumber>#{user.uid_number}</uidNumber>
  <userCertificate binary="true">#{certificate}</userCertificate>
  <userPassword>#{user.user_password}</userPassword>
</user>
EOX
    end
  end

  def test_save
    make_temporary_user do |user, password|
      user.sn = nil
      assert(!user.save)
      assert_raises(ActiveLdap::EntryInvalid) do
        user.save!
      end

      user.sn = "Surname"
      assert(user.save)
      user.sn = "Surname2"
      assert_nothing_raised {user.save!}
    end
  end

  def test_have_attribute?
    make_temporary_user do |user, password|
      assert(user.have_attribute?(:cn))
      assert(user.have_attribute?(:commonName))
      assert(user.have_attribute?(:common_name))
      assert(!user.have_attribute?(:commonname))
      assert(!user.have_attribute?(:COMMONNAME))

      assert(!user.have_attribute?(:unknown_attribute))
    end
  end

  def test_attribute_present?
    make_temporary_user do |user, password|
      assert(user.attribute_present?(:sn))
      user.sn = nil
      assert(!user.attribute_present?(:sn))
      user.sn = "Surname"
      assert(user.attribute_present?(:sn))
      user.sn = [nil]
      assert(!user.attribute_present?(:sn))
    end
  end

  def test_attribute_present_with_unknown_attribute
    make_temporary_user do |user, password|
      assert(!user.attribute_present?(:unknown_attribute))
    end
  end

  def test_update_all
    make_temporary_user do |user, password|
      make_temporary_user do |user2, password|
        user2_cn = user2.cn
        new_cn = "New #{user.cn}"
        @user_class.update_all({:cn => new_cn}, user.uid)
        assert_equal(new_cn, @user_class.find(user.uid).cn)
        assert_equal(user2_cn, @user_class.find(user2.uid).cn)

        new_sn = "New SN"
        @user_class.update_all({:sn => [new_sn]})
        assert_equal(new_sn, @user_class.find(user.uid).sn)
        assert_equal(new_sn, @user_class.find(user2.uid).sn)

        new_sn2 = "New SN2"
        @user_class.update_all({:sn => [new_sn2]}, user2.uid)
        assert_equal(new_sn, @user_class.find(user.uid).sn)
        assert_equal(new_sn2, @user_class.find(user2.uid).sn)
      end
    end
  end

  def test_update
    make_temporary_user do |user, password|
      new_cn = "New #{user.cn}"
      new_user = @user_class.update(user.dn, {:cn => new_cn})
      assert_equal(new_cn, new_user.cn)

      make_temporary_user do |user2, password|
        new_sns = ["New SN1", "New SN2"]
        new_cn2 = "New #{user2.cn}"
        new_user, new_user2 = @user_class.update([user.dn, user2.dn],
                                                 [{:sn => new_sns[0]},
                                                  {:sn => new_sns[1],
                                                   :cn => new_cn2}])
        assert_equal(new_sns, [new_user.sn, new_user2.sn])
        assert_equal(new_cn2, new_user2.cn)
      end
    end
  end

  private
  def detect_modify(object)
    modify_called = false
    singleton_class = class << object; self; end
    singleton_class.send(:define_method, :modify_entry) do |*args|
      dn, attributes, options = args
      options ||= {}
      modify_detector = Object.new
      modify_detector.instance_variable_set("@called", false)
      def modify_detector.modify(dn, entries, options)
        @called = true
      end
      options[:connection] = modify_detector
      result = super(dn, attributes, options)
      modify_called = modify_detector.instance_variable_get("@called")
      result
    end
    yield
    modify_called
  end

  def assert_to_ldif(entry)
    records = ActiveLdap::LDIF.parse(entry.to_ldif).records
    parsed_entries = records.collect do |record|
      entry.class.send(:instantiate, [record.dn, record.attributes])
    end
    assert_equal([entry], parsed_entries)
  end
end