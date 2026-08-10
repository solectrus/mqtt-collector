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
    Dentaku(self.class.normalized_expression(expression), bound_values)
  end

  private

  # Only bind variables that actually have a value. Dentaku's comparison
  # operators (==, !=) happily compare against an explicit nil instead of
  # raising, so a bound-but-nil variable would silently be treated as a real,
  # distinct value rather than "unknown" - unlike arithmetic operators, which
  # do raise. Leaving the variable out entirely makes Dentaku treat it as
  # unbound, which raises Dentaku::UnboundVariableError for every operator.
  # Dentaku::Calculator#evaluate, which Dentaku() calls, rescues all of these
  # errors and returns nil, so an unknown value gives an unresolved result.
  # A false value is a real value and stays bound - only nil is skipped.
  def bound_values
    self.class.variables_in(expression).filter_map do |variable|
      val = value(variable)
      [self.class.normalized_variable(variable), val] unless val.nil?
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
end
