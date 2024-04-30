require 'evaluator'

describe Evaluator do
  subject(:evaluator) { described_class.new(expression:, data:) }

  context 'with valid expression' do
    let(:expression) { '({a} + {b}) / 2' }
    let(:data) { { 'a' => 2, 'b' => 5 } }

    it 'evaluates the expression' do
      expect(evaluator.run).to eq(3.5)
    end
  end

  context 'with valid expression using JSONPath' do
    let(:expression) { '({$.a} + {$.b}) / 2' }
    let(:data) { { 'a' => 2, 'b' => 5 } }

    it 'evaluates the expression' do
      expect(evaluator.run).to eq(3.5)
    end
  end

  context 'with valid expression using more complex JSONPath' do
    let(:expression) { '{$.c.d[1]} + {a}' }
    let(:data) { { 'a' => 1, 'b' => 2, 'c' => { 'd' => [3, 42, 4] } } }

    it 'evaluates the expression' do
      expect(evaluator.run).to eq(43)
    end
  end

  context 'with valid expression using vars with spaces' do
    let(:expression) { '({this is a} + {this is b}) / 2' }
    let(:data) { { 'this is a' => 2, 'this is b' => 5 } }

    it 'evaluates the expression' do
      expect(evaluator.run).to eq(3.5)
    end
  end

  context 'with invalid expression (missing curley braces)' do
    let(:expression) { '(a + b) / 2' }
    let(:data) { { 'a' => 2, 'b' => 5 } }

    it 'returns nil' do
      expect(evaluator.run).to be_nil
    end
  end

  context 'with invalid expression (open curley braces)' do
    let(:expression) { '({a} + {b) / 2' }
    let(:data) { { 'a' => 2, 'b' => 5 } }

    it 'returns nil' do
      expect(evaluator.run).to be_nil
    end
  end

  context 'with invalid expression (missing parenthesis)' do
    let(:expression) { '{a} + {b}) / 2' }
    let(:data) { { 'a' => 2, 'b' => 5 } }

    it 'returns nil' do
      expect(evaluator.run).to be_nil
    end
  end

  context 'with invalid expression (missing divisor)' do
    let(:expression) { '({a} + {b}) / ' }
    let(:data) { { 'a' => 2, 'b' => 5 } }

    it 'returns nil' do
      expect(evaluator.run).to be_nil
    end
  end

  context 'with missing data' do
    let(:expression) { '({a} + {b}) / 2' }
    let(:data) { { 'a' => 2 } }

    it 'returns nil' do
      expect(evaluator.run).to be_nil
    end
  end

  context 'with division by zero' do
    let(:expression) { '({a} + {b}) / {b}' }
    let(:data) { { 'a' => 2, 'b' => 0 } }

    it 'returns nil' do
      expect(evaluator.run).to be_nil
    end
  end
end
