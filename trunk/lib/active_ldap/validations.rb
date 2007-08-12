require 'active_record/validations'

module ActiveLdap
  module Validations
    def self.append_features(base)
      super

      base.class_eval do
        alias_method :new_record?, :new_entry?
        include ActiveRecord::Validations

        # Workaround for GetText's ugly implementation
        begin
          instance_method(:save_without_validation)
        rescue NameError
          alias_method_chain :save, :validation
          alias_method_chain :save!, :validation
          alias_method_chain :update_attribute, :validation_skipping
        end

        validate :validate_required_values

        class << self
          def evaluate_condition_with_active_ldap_support(condition, entry)
            evaluate_condition_without_active_ldap_support(condition, entry)
          rescue ActiveRecord::ActiveRecordError
            raise Error, $!.message
          end
          alias_method_chain :evaluate_condition, :active_ldap_support
        end

        def save_with_active_ldap_support!
          save_without_active_ldap_support!
        rescue ActiveRecord::RecordInvalid
          raise EntryInvalid, $!.message
        end
        alias_method_chain :save!, :active_ldap_support

        def valid?
          ensure_apply_object_class
          super
        end

        # validate_required_values
        #
        # Basic validation:
        # - Verify that every 'MUST' specified in the schema has a value defined
        def validate_required_values
          # Make sure all MUST attributes have a value
          @musts.each do |object_class, attributes|
            attributes.each do |required_attribute|
              # Normalize to ensure we catch schema problems
              real_name = to_real_attribute_name(required_attribute, true)
              raise UnknownAttribute.new(required_attribute) if real_name.nil?
              # # Set default if it wasn't yet set.
              # @data[real_name] ||= [] # need?
              value = @data[real_name] || []
              # Check for missing requirements.
              if value.empty?
                aliases = schema.attribute_aliases(real_name) - [real_name]
                args = [object_class]
                if ActiveLdap.const_defined?(:GetTextFallback)
                  if aliases.empty?
                    format = "is required attribute by objectClass '%s'"
                  else
                    format = "is required attribute by objectClass '%s'" \
                             ": aliases: %s"
                    args << aliases.join(', ')
                  end
                else
                  if aliases.empty?
                    format = "%{fn} is required attribute by objectClass '%s'"
                  else
                    format = "%{fn} is required attribute by objectClass '%s'" \
                             ": aliases: %s"
                    args << aliases.join(', ')
                  end
                end
                errors.add(real_name, format % args)
              end
            end
          end
        end

        private
        def run_validations_with_active_ldap_support(validation_method)
          run_validations_without_active_ldap_support(validation_method)
        rescue ActiveRecord::ActiveRecordError
          raise Error, $!.message
        end
        alias_method_chain :run_validations, :active_ldap_support
      end
    end
  end
end
