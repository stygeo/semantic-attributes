# Marks an attribute as required.
#
# You can require associations by name. Currently only works for singular associations (has_one, belongs_to).
#
# Example:
#   class Comment < ActiveRecord::Base
#     has_one :owner
#     subject_is_required
#     owner_is_required
#   end
class Predicates::Required < Predicates::Base
  def error_message
    @error_message || ' is required.'
  end

  def validate(value, record)
    valid = true
    if value.kind_of?(ActiveRecord::Base) and value.new_record?
      valid &&= value.valid?
    else
      valid &&= (!value.nil?)
      valid &&= !(value.respond_to?(:empty?) and value.empty?)
    end
    valid
  end
end