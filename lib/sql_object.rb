require_relative 'db_connection'
require 'active_support/inflector'
require 'active_support/core_ext/string'


class SQLObject
  def self.columns

    if @columns.nil?
      columns = DBConnection.execute2(<<-SQL).to_a
        SELECT
          *
        FROM
          #{self.table_name}
      SQL

      @columns = columns.first.map { |column| column.to_sym }
    else
      @columns
    end
  end

  def self.finalize!
    columns.each do |column|

      define_method("#{column}=") do |arg|
        attributes[column] = arg
      end

      define_method("#{column}") do
        attributes[column]
      end

    end

  end

  def self.table_name=(table_name)

    @table_name = table_name
  end

  def self.table_name

    @table_name.nil? ? @table_name = self.to_s.pluralize.tableize : @table_name
  end

  def self.all

    collection = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        #{self.table_name}
    SQL

    self.parse_all(collection)

  end

  def self.parse_all(results)

    results.map { |obj_vars| self.new(obj_vars) }

  end

  def self.find(id)

    obj_vars = DBConnection.execute(<<-SQL, id: id).first
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        id = :id
    SQL

    obj_vars.nil? ? nil : self.new(obj_vars)
  end

  def initialize(params = {})

    params.each do |key, value|
      if self.class.columns.include?(key.to_sym)
        self.send("#{key}=".to_sym, value)
      else
        raise "unknown attribute '#{key.to_s}'"
      end

    end
  end

  def attributes

    @attributes ||= {}
  end

  def attribute_values

    @attributes.values
  end

  def insert

    cols = self.class.columns
    column_names = cols[1..-1].join(', ')
    question_marks = (["?"] * (cols.count - 1) ).join(', ')
    vals = self.attribute_values

    DBConnection.execute(<<-SQL, *vals)
      INSERT INTO
        #{self.class.table_name} (#{column_names})
      VALUES
        (#{question_marks})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update

    cols = self.class.columns.drop(1)
    vals = self.attribute_values.drop(1)
    column_names = cols.map { |name| "#{name} = ?" }.join(', ')

    DBConnection.execute(<<-SQL, *vals, self.id)
      UPDATE
        #{self.class.table_name}
      SET
        #{column_names}
      WHERE
        id = ?
    SQL
  end

  def destroy
    vals = self.attribute_values.drop(1)

    DBConnection.execute(<<-SQL, *vals, self.id)
      DELETE
      FROM
        #{self.class.table_name}
      WHERE
        id = ?
    SQL
  end

  def save
    self.id.nil? ? self.insert : self.update
  end
end
