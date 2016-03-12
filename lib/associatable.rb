require_relative 'searchable'
require 'active_support/inflector'
require 'active_support/core_ext/string'

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
    end
  end

  def has_one_through(name, through_name, source_name)
    define_method(name) do
       through_options = self.class.assoc_options[through_name]
       source_options =
         through_options.model_class.assoc_options[source_name]

       through_table = through_options.table_name
       through_pk = through_options.primary_key
       through_fk = through_options.foreign_key

       source_table = source_options.table_name
       source_pk = source_options.primary_key
       source_fk = source_options.foreign_key

       key_val = self.send(through_fk)
       results = DBConnection.execute(<<-SQL, key_val)
         SELECT
           #{source_table}.*
         FROM
           #{through_table}
         JOIN
           #{source_table}
         ON
           #{through_table}.#{source_fk} = #{source_table}.#{source_pk}
         WHERE
           #{through_table}.#{through_pk} = ?
       SQL

       source_options.model_class.parse_all(results).first
    end
  end


  def has_many_through(name, through_name, source_name)
    define_method(name) do
       through_options = self.class.assoc_options[through_name]
       source_options =
         through_options.model_class.assoc_options[source_name]

       through_table = through_options.table_name
       through_pk = through_options.primary_key
       through_fk = through_options.foreign_key

       source_table = source_options.table_name
       source_pk = source_options.primary_key
       source_fk = source_options.foreign_key

       key_val = self.send(through_fk)
       results = DBConnection.execute(<<-SQL, key_val)
         SELECT
           #{source_table}.*
         FROM
           #{through_table}
         JOIN
           #{source_table}
         ON
           #{through_table}.#{through_fk} = #{source_table}.#{source_pk}
         WHERE
           #{through_table}.#{through_pk} = ?
       SQL

       through_options.model_class.parse_all(results)
    end

  end

  def includes(association)

    self_table = self.table_name
    self_id = "#{self.class_name}_id"
    association_table = table.table_name

    results = DBConnection.execute(<<-SQL)

      SELECT
        *
      FROM
        #{self_table}
      JOIN
        #{association_table}
      ON
        #{self_table}.id = #{association_table}.#{self_id}
      WHERE
        #{association_table}.#{self_id} = #{self.id}

    SQL

    self.model_class.parse_all(results)

  end

  def joins(table)

    self_table = self.table_name
    self_id = "#{self.class_name}_id"
    join_table = table.table_name

    results = DBConnection.execute(<<-SQL)

      SELECT
        *
      FROM
        #{self_table}
      JOIN
        #{join_table}
      ON
        #{self_table}.id = #{join_table}.#{self_id}

    SQL

    self.model_class.parse_all(results)

  end

  def assoc_options

    @assoc_options ||= {}
    @assoc_options
  end
end

class SQLObject

  extend Associatable
end
