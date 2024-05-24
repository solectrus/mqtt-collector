class Evaluator
  attr_reader :expression, :data

  def initialize(expression:, data:)
    @expression = expression
    @data = data
  end

  def run
    # Get variables used in the expression
    variables = extract_variables_from_expression

    # Get values for each of this variables
    values = extract_values_from_data(variables)

    # Evaluate the expression
    Dentaku(normalized_expression, values)
  end

  private

  def extract_variables_from_expression
    expression.scan(/{(.*?)}/).flatten
  end

  def extract_values_from_data(vars)
    vars.to_h { |var| [normalized_variable(var), value(var)] }
  end

  def value(variable)
    if variable.start_with?('$.')
      JsonPath.new(variable).first(data)
    else
      data[variable]
    end
  end

  # Replace all variables by their normalized version
  def normalized_expression
    expression.gsub(/{(.*?)}/) do |variable|
      normalized_variable(variable)
    end
  end

  # Remove curly braces and replace all non-alphanumeric characters by underscore
  def normalized_variable(variable)
    variable.gsub(/[{}]/, '').gsub(/[^0-9a-z]/i, '_')
  end
end
