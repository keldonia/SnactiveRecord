require_relative 'db_connection'
require_relative 'sql_object'

module Searchable
  def where(params)

    where_line = params.keys.map { |key| "#{key} = ?" }.join(" AND ")

    collection = DBConnection.execute(<<-SQL, *params.values)
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        #{where_line}
    SQL

    self.parse_all(collection)
  end

end

class SQLObject
  extend Searchable
end
