require_relative 'searchable'

class Validator

  def presence(attribute)
    self.send(attribute.to_sym) ? true : false
  end

  

end


class SQLObject

  extend Validator
end
