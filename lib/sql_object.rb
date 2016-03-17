require_relative 'db_connection'
require 'active_support/inflector'
require 'active_support/core_ext/string'
require_relative 'associatable'
require_relative 'relation'


class SQLObject
  extend Associatable

  RELATION_METHODS = [
    :limit, :includes, :where, :order
  ]

  RELATION_METHODS.each do |method|
    define_singleton_method(method) do |arg|
      SQLRelation.new(klass: self).send(method, arg)
    end
  end

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
    where({})
  end

  def self.count
    all.count
  end

  def self.first
    all.limit(1).first
  end

  def self.last
    all.order(id: :desc).limit(1).first
  end

  def self.uniq
    all.uniq
  end

  def self.parse_all(results)
    relation = SQLRelation.new(klass: self, loaded: true)
    results.each do |result|
      relation << self.new(result)
    end

    relation
  end

  def self.has_association?(association)
    assoc_options.keys.include?(association)
  end

  def self.define_singleton_method_by_proc(onj, name, block)
    metaclass = class << obj; self; end
    metaclass.send(:define_method, name, block)
  end

  def self.find(id)
    where(id: id).first
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
    if self.class.find(id)

    DBConnection.execute(<<-SQL, *vals, self.id)
      DELETE
      FROM
        #{self.class.table_name}
      WHERE
        id = ?
    SQL

    return self
  end

  def save
    self.id.nil? ? self.insert : self.update
  end
end
