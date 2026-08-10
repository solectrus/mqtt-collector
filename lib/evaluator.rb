require 'bigdecimal'
require 'dentaku'

# Dentaku tokenizes and parses an expression again on every evaluation, which
# costs more than the calculation itself. Every expression comes from the
# configuration and never changes, so the cache stays small.
Dentaku.enable_ast_cache!

class Evaluator
  # Raised for a broken expression, so a caller does not need to know which
  # engine evaluates it.
  class Error < StandardError
  end

  # The names of all {...} placeholders of an expression
  def self.variables_in(expression)
    expression.to_s.scan(/{(.*?)}/).flatten.uniq
  end

  # Parses the expression without any value, which finds a syntax error or an
  # unknown function. Raises an Evaluator::Error if the expression is broken.
  def self.parse!(expression)
    Dentaku::Calculator.new.ast(normalized_expression(expression))
  rescue Dentaku::Error => e
    raise Error, e.message
  end

  # Replace all variables by their normalized version
  def self.normalized_expression(expression)
    expression.gsub(/{(.*?)}/) { |variable| normalized_variable(variable) }
  end

  # Remove curly braces, replace all non-alphanumeric characters by underscore
  # and downcase. Dentaku compares variable names case-insensitively, so the
  # normalization must do the same. Otherwise {Washer} and {washer} look like
  # two variables here, but are one for Dentaku.
  def self.normalized_variable(variable)
    variable.gsub(/[{}]/, '').gsub(/[^0-9a-z]/i, '_').downcase
  end

  attr_reader :expression, :data

  def initialize(expression:, data:)
    @expression = expression
    @data = data
  end

  def run
    values =
      self.class.variables_in(expression).to_h do |variable|
        [self.class.normalized_variable(variable), value(variable)]
      end

    Dentaku(self.class.normalized_expression(expression), values)
  end

  private

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
end
