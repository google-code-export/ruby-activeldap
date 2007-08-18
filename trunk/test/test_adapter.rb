require 'al-test-utils'

class TestAdapter < Test::Unit::TestCase
  include AlTestUtils

  def setup
  end

  def teardown
  end

  priority :must

  priority :normal
  def test_filter_with_escaped_character
    assert_parse_filter("(uid=Alice\\3DBob)", {:uid => "Alice=Bob"})
    assert_parse_filter("(uid=Alice\\2CBob)", {:uid => "Alice,Bob"})
    assert_parse_filter("(uid=Alice\\3DBob\\2C)", {:uid => "Alice=Bob,"})
    assert_parse_filter("(uid=Alice\\3D\\2CBob)", {:uid => "Alice=,Bob"})
  end

  def test_empty_filter
    assert_parse_filter(nil, nil)
    assert_parse_filter(nil, "")
    assert_parse_filter(nil, "   ")
  end

  def test_simple_filter
    assert_parse_filter("(objectClass=*)", "objectClass=*")
    assert_parse_filter("(objectClass=*)", "(objectClass=*)")
    assert_parse_filter("(&(uid=bob)(objectClass=*))",
                        "(&(uid=bob)(objectClass=*))")

    assert_parse_filter("(objectClass=*)", {:objectClass => "*"})
    assert_parse_filter("(&(objectClass=*)(uid=bob))",
                        {:uid => "bob", :objectClass => "*"})

    assert_parse_filter("(&(uid=bob)(objectClass=*))",
                        [:and, "uid=bob", "objectClass=*"])
    assert_parse_filter("(&(uid=bob)(objectClass=*))",
                        [:&, "uid=bob", "objectClass=*"])
    assert_parse_filter("(|(uid=bob)(objectClass=*))",
                        [:or, "uid=bob", "objectClass=*"])
    assert_parse_filter("(|(uid=bob)(objectClass=*))",
                        [:|, "uid=bob", "objectClass=*"])
  end

  def test_multi_value_filter
    assert_parse_filter("(&(objectClass=top)(objectClass=posixAccount))",
                        {:objectClass => ["top", "posixAccount"]})

    assert_parse_filter("(&(objectClass=top)(objectClass=posixAccount))",
                        [[:objectClass, "top"],
                         [:objectClass, "posixAccount"]])
    assert_parse_filter("(&(objectClass=top)(objectClass=posixAccount))",
                        [[:objectClass, ["top", "posixAccount"]]])
  end

  def test_nested_filter
    assert_parse_filter("(&(objectClass=*)(uid=bob))",
                        [:and, {:uid => "bob", :objectClass => "*"}])
    assert_parse_filter("(&(objectClass=*)(|(uid=bob)(uid=alice)))",
                        [:and, {:objectClass => "*"},
                         [:or, [:uid, "bob"], [:uid, "alice"]]])
    assert_parse_filter("(&(objectClass=*)(|(uid=bob)(uid=alice)))",
                        [:and,
                         {:objectClass => "*",
                          :uid => [:or, "bob", "alice"]}])
    assert_parse_filter("(&(gidNumber=100001)" +
                        "(|(uid=temp-user1)(uid=temp-user2)))",
                        [:and,
                         [:and, {"gidNumber"=>["100001"]}],
                         [:or, {"uid"=>["temp-user1", "temp-user2"]}]])
    assert_parse_filter("(&(gidNumber=100001)" +
                        "(objectClass=person)(objectClass=posixAccount))",
                        [:and,
                         [:or, ["gidNumber", "100001"]],
                         ["objectClass", "person"],
                         ["objectClass", "posixAccount"]])
  end

  def test_invalid_operator
    assert_raises(ArgumentError) do
      assert_parse_filter("(&(objectClass=*)(uid=bob))",
                          [:xxx, {:uid => "bob", :objectClass => "*"}])
    end
  end

  private
  def assert_parse_filter(expected, filter)
    adapter = ActiveLdap::Adapter::Base.new
    assert_equal(expected, adapter.send(:parse_filter, filter))
  end
end