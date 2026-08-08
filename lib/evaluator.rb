require 'bigdecimal'

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

  # Only bind variables that actually have a value. Dentaku's comparison
  # operators (==, !=) happily compare against an explicit nil instead of
  # raising, so a bound-but-nil variable would silently be treated as a real,
  # distinct value rather than "unknown" - unlike arithmetic operators, which
  # do raise (and get rescued below into an overall nil result). Leaving the
  # variable out entirely makes Dentaku treat it as unbound, which errors out
  # (rescued into nil) consistently for every operator.
  def extract_values_from_data(vars)
    vars.filter_map do |var|
      val = value(var)
      [normalized_variable(var), val] unless val.nil?
    end.to_h
  end

  def value(variable)
    raw =
      if variable.start_with?('$.')
        JsonPath.new(variable).first(data)
      else
        data[variable]
      end

    precise(raw)
  end

  # Dentaku parses numeric literals as BigDecimal, but leaves injected values
  # untouched. Mixing both would make Float rounding errors leak into the
  # result (e.g. 35.2 - 20.5 => 14.700000000000003), so convert to BigDecimal.
  def precise(value)
    value.is_a?(Float) ? BigDecimal(value.to_s) : value
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
