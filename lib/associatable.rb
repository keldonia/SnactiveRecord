require 'active_support/inflector'
require 'active_support/core_ext/string'
require 'byebug'

class AssocOptions
  attr_accessor(
    :foreign_key,
    :class_name,
    :primary_key
  )

  def model_class
    @class_name.constantize
  end

  def table_name
    model_class.table_name
  end
end

class BelongsToOptions < AssocOptions
  def initialize(name, options = {})
    defaults = {
      foreign_key: "#{name}_id".to_sym,
      class_name: name.to_s.camelcase,
      primary_key: :id
    }

    defaults.keys.each do |key|
      self.send("#{key}=", options[key] || defaults[key])
    end
  end
end

class HasManyOptions < AssocOptions
  def initialize(name, self_class_name, options = {})
    defaults = {
      foreign_key: "#{self_class_name.underscore}_id".to_sym,
      class_name: name.to_s.singularize.camelcase,
      primary_key: :id
    }

    defaults.keys.each do |key|
      self.send("#{key}=", options[key] || defaults[key])
    end
  end
end

module Associatable

  def belongs_to(name, options = {})
    self.assoc_options[name] = BelongsToOptions.new(name, options)

    define_method(name) do
      options = self.class.assoc_options[name]

      key_val = self.send(options.foreign_key)
      options
        .model_class
        .where(options.primary_key => key_val)
        .first
    end
  end

  def has_many(name, options = {})
    self.assoc_options[name] =
      HasManyOptions.new(name, self.name, options)

    define_method(name) do
      options = self.class.assoc_options[name]

      key_val = self.send(options.primary_key)

      options
        .model_class
        .where(options.foreign_key => key_val)
        .to_a
    end
  end

  def has_one_through(name, through_name, source_name)
    define_method(name) do
       through_options = self.class.assoc_options[through_name]
       source_options =
         through_options.model_class.assoc_options[source_name]

       through_pk = through_options.primary_key
       through_fk = through_options.foreign_key

       key_val = self.send(through_fk)

       source_options
        .model_class
        .includes(through_name)
        .where(through_pk => key_val)
        .first
    end
  end


  def has_many_through(name, through_name, source_name)
    define_method(name) do
       through_options = self.class.assoc_options[through_name]

       through_fk = through_options.foreign_key

       key_val = self.send(through_fk)

       through_options.model_class.parse_all(results)

       through_name
        .model_class
        .where(through_fk => key_val)
        .includes(source_name)
        .load
        .included_relations
        .first
        .to_a
    end
  end

  def assoc_options

    @assoc_options ||= {}
    @assoc_options
  end
end
