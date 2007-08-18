module ActiveLdap
  module ObjectClass
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def classes
        required_classes.collect do |name|
          schema.object_class(name)
        end
      end
    end

    def add_class(*target_classes)
      replace_class((classes + target_classes.flatten).uniq)
    end

    def ensure_recommended_classes
      add_class(self.class.recommended_classes)
    end

    def remove_class(*target_classes)
      replace_class((classes - target_classes.flatten).uniq)
    end

    def replace_class(*target_classes)
      new_classes = target_classes.flatten.uniq
      assert_object_classes(new_classes)
      if new_classes.sort != classes.sort
        set_attribute('objectClass', new_classes)
      end
    end

    def classes
      (get_attribute('objectClass', true) || []).dup
    end

    private
    def assert_object_classes(new_classes)
      assert_valid_object_class_value_type(new_classes)
      assert_valid_object_class_value(new_classes)
      assert_have_all_required_classes(new_classes)
    end

    def assert_valid_object_class_value_type(new_classes)
      invalid_classes = new_classes.reject do |new_class|
        new_class.is_a?(String)
      end
      unless invalid_classes.empty?
        format = _("Value in objectClass array is not a String: %s")
        invalid_classes_info = invalid_classes.collect do |invalid_class|
          "#{invalid_class.class}:#{invalid_class.inspect}"
        end.join(", ")
        raise TypeError, format % invalid_classes_info
      end
    end

    def assert_valid_object_class_value(new_classes)
      invalid_classes = new_classes.reject do |new_class|
        schema.exist_name?("objectClasses", new_class)
      end
      unless invalid_classes.empty?
        format = _("unknown objectClass in LDAP server: %s")
        message = format % invalid_classes.join(', ')
        raise ObjectClassError, message
      end
    end

    def assert_have_all_required_classes(new_classes)
      _schema = schema
      normalized_new_classes = new_classes.collect(&:downcase)
      required_classes = self.class.required_classes.reject do |required_class|
        normalized_new_classes.include?(required_class.downcase) or
          (normalized_new_classes.find do |new_class|
             _schema.object_class(new_class).super_class?(required_class)
           end)
      end
      unless required_classes.empty?
        format = _("Can't remove required objectClass: %s")
        message = format % required_classes.join(", ")
        raise RequiredObjectClassMissed, message
      end
    end
  end
end