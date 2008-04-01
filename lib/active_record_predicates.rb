# active record tie-ins
module ActiveRecord
  module Predicates
    def self.included(base)
      base.extend ClassMethods
      base.validate :validate_predicates
      base.write_inheritable_attribute :semantic_attributes, SemanticAttributes.new
      base.class_inheritable_reader :semantic_attributes
    end

    # the validation hook that checks all predicates
    def validate_predicates
      semantic_attributes.each do |attribute|
        attribute.predicates.each do |predicate|
          case predicate.validate_if
            when Symbol
            next unless send(predicate.validate_if)

            when Proc
            next unless predicate.validate_if.call(self)
          end

          case predicate.validate_on
            when :create
            next unless new_record?

            when :update
            next if new_record?
          end

          value = self.send(attribute.field)
          if (value.nil? or (value.respond_to? :empty? and value.empty?))
            # it's empty, so add an error or not but either way move along
            self.errors.add(attribute.field, _(predicate.error_message)) unless predicate.allow_empty?
            next
          end

          unless predicate.validate(value, self)
            self.errors.add(attribute.field, _(predicate.error_message))
          end
        end
      end
    end

    module ClassMethods
      # Provides sugary syntax for adding and querying predicates
      #
      # The syntax supports the following forms:
      #   #{attribute}_is_#{predicate}(options = {})
      #   #{attribute}_is_a_#{predicate}(options = {})
      #   #{attribute}_is_an_#{predicate}(options = {})
      #   #{attribute}_has_#{predicate}(options = {})
      #   #{attribute}_has_a_#{predicate}(options = {})
      #   #{attribute}_has_an_#{predicate}(options = {})
      #
      # If you want to assign a predicate to multiple fields, you may replace the attribute component with the word 'fields', and pass a field list as the first argument, like this:
      #   fields_are_#{predicate}(fields = [], options = {})
      #
      # Each form may also have a question mark at the end, to query whether the attribute has the predicate
      #
      # In order to avoid clashing with other method_missing setups, this syntax is checked *last*, after all other method_missing metaprogramming attempts have failed.
      def method_missing(name, *args)
        begin
          super
        rescue NameError
          if /^(.*)_(is|has)_(an?_)?([^?]*)(\?)?$/.match(name.to_s)
            options = args.pop if args.last.is_a? Hash
            fields = ($1 == 'fields') ? args : [$1]
            predicate = $4
            if $5 == '?'
              self.semantic_attributes[fields.first].has? predicate
            else
              args = [predicate]
              args << options if options
              fields.each do |field|
                self.semantic_attributes[field].add *args
              end
            end
          else
            raise
          end
        end
      end

      # Provides a way to pre-validate a single value out of context of
      # an entire record. This is helpful for validating parts of a form
      # before it has been submitted.
      #
      # For values that are (in)valid only in context, such as the common
      # :password_confirmation (which is only valid with a matching :password),
      # additional values may be specified.
      #
      # Returns first error message if value is expected invalid.
      #
      # Example:
      #   User.expected_error_for(:username, "bob")
      #   => "has already been taken."
      #   User.expected_error_for(:username, "bob2392")
      #   => nil
      #   User.expected_error_for(:password_confirmation, "mismatched", :password => "opensesame")
      #   => "must be the same as password."
      def expected_error_for(attribute, value, extra_values = {})
        @record = self.new(extra_values)
        semantic_attributes[attribute.to_sym].predicates.each do |predicate|
          return predicate.error_message unless predicate.validate(value, @record)
        end
        nil
      end
    end
  end
end