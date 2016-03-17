require_relative './db_connection'
require_relative 'sql_object'

class SQLRelation

  def self.build_association(base, included, method_name)
    base.included_relations << included

    assoc_options = base.klass.assoc_options[method_name]
    has_many = assoc_options.class == HasManyOptions

    if has_many
      include_send = assoc_options.foreign_key
      base_send = assoc_options.primary_key
    else
      include_send = assoc_options.primary_key
      base_send = assoc_options.foreign_key
    end

    match = proc do
      selection = included.select do |include_sql_obj|
        include_sql_obj.send(include_send) == self.send(base_send)
      end

      associated = has_many ? selection : selection.first

      new_match = proc { associated }
      SQLObject.define_singleton_method_by_proc(
        self, method_name, new_match
      )

      associated
    end

    base.collection.each do |base_sql_obj|
      SQLObject.define_singleton_method_by_proc(
        base_sql_obj, method_name, match
      )
    end
  end

  attr_reader :klass, :collection, :loaded, :sql_count, :sql_limit, :uniq
  attr_accessor :included_relations

  def initialize(options)
    defaults = {
      klass: nil,
      loaded: false,
      collection: []
    }

    @klass = options[:klass]
    @collection = options[:collection] || defaults[:collection]
    @loaded = options[:loaded] || defaults[:loaded]
  end

  def <<(item)
    if item.class == klass
      @collection << item
    end
  end

  def count
    @sql_count = true
    load
  end

  def uniq
    @distinct = true
    load
  end

  def included_relations
    @included_relations ||= []
  end

  def includes(klass)
    includes_params << klass
    self
  end

  def includes_params
    @includes_params ||= []
  end

  def limit(n)
    @sql_limit = n
    self
  end

  def joins(relation)
    load
    p joins
    puts "LOADING #{relation.to_s}"
    assoc = klass.assoc_options[param]
    f_k = assoc.foreign_key
    p_k = assoc.primary_key
    joins_table = assoc.table_name.to_s

    results = DBConnection.execute(<<-SQL)
    SELECT
      *
    FROM
      #{self.table_name}
    JOIN
      #{joins_table}
    ON
      #{f_k} = #{p_k}
    SQL

    results = parse_all(results)
  end

  def load
    if !loaded
      select_statement = uniq ? "DISTINCT #{self.table_name.to_s}.*" : "#{self.table_name.to_s}.*"
      select_statement = sql_count ? "COUNT(select_statement)" : select_statement
      puts "LOADING #{table_name}"
      results = DBConnection.execute(<<-SQL, sql_params[:values])
        SELECT
          #{ select_statement }
        FROM
          #{ self.table_name }
          #{ sql_params[:where] }
          #{ sql_params[:params] }
          #{ order_by_string }
          #{ "LIMIT #{sql_limit}" if sql_limit }
      SQL

      results = sql_count ? results.first.values.first : parse_all(results)
    end

    results = results || self

    unless includes_params.empty?
      results = load_includes(results)
    end

    results
  end


  def load_includes(relation)
    includes_params.each do |param|
      if relation.klass.has_association?(param)
        p relation
        puts "LOADING #{param.to_s}"
        assoc = klass.assoc_options[param]
        f_k = assoc.foreign_key
        p_k = assoc.primary_key
        includes_table = assoc.table_name.to_s
        in_ids = relation.collection.map do |sql_obj|
          sql_obj.id
        end.join(", ")

        has_many = assoc.class == HasManyOptions

        results = DBConnection.execute(<<-SQL)
        SELECT
          #{includes_table}.*
        FROM
          #{includes_table}
        WHERE
          #{includes_table}.#{has_many ? f_k : p_k}
        IN
          (#{in_ids});
        SQL

        included = assoc.model_class.parse_all(results)
        SQLRelation.build_association(relation, included, param)

      end
    end

    relation
  end

  def method_missing(method, *args, &block)
    self.to_a.send(method, *args, &block)
  end

  def order(params)
    if params.is_a?(Hash)
      order_params_hash.merge!(params)
    else
      order_params_hash.merge!(params: :asc)
    end

    self
  end

  def order_params_hash
    @order_params_hash ||= {}
  end

  def order_by_string
    order_string = order_params_hash.map do |column, asc_desc|
      "#{column} #{asc_desc.to_s.upcase}"
    end.join(", ")

    order_string.empty? ? "" : "ORDER BY #{order_string}"
  end

  def parse_all(attributes)
    klass
      .parse_all(attributes)
      .where(where_params_hash)
      .includes(includes_params)
  end

  def sql_params
    params, values = [], []

    i = 1

    where_params_hash.map do |attribute, value|
      params << "#{attribute} = $#{i}"
      values << value
      i += 1
    end

    {
      params: params.join(" AND "),
      where: params.empty? ? nil : "WHERE",
      values: values
    }
  end

  def table_name
    klass.table_name
  end

  def to_a
    self.load.collection
  end

  def where_params_hash
    @where_params_hash ||= {}
  end

  def where(params)
    where_params_hash.merge!(params)
    self
  end
end
