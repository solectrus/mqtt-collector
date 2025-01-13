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

  context 'with valid expression using IF' do
    let(:expression) { "IF({x} > {y} AND {x} < {z}, 'TRUE', 'FALSE')" }

    context 'when condition is true' do
      let(:data) { { 'x' => 6, 'y' => 2, 'z' => 10 } }

      it 'evaluates the expression' do
        expect(evaluator.run).to eq('TRUE')
      end
    end

    context 'when condition is false' do
      let(:data) { { 'x' => 1, 'y' => 3, 'z' => 10 } }

      it 'evaluates the expression' do
        expect(evaluator.run).to eq('FALSE')
      end
    end
  end

  context 'with valid expression using nested IF' do
    let(:expression) { "IF({x} == {y}, 'EQUAL', IF({x} > {y}, 'GREATER', 'LESS'))" }

    context 'when case 1' do
      let(:data) { { 'x' => 6, 'y' => 2 } }

      it 'evaluates the expression' do
        expect(evaluator.run).to eq('GREATER')
      end
    end

    context 'when case 2' do
      let(:data) { { 'x' => 6, 'y' => 6 } }

      it 'evaluates the expression' do
        expect(evaluator.run).to eq('EQUAL')
      end
    end

    context 'when case 3' do
      let(:data) { { 'x' => 6, 'y' => 7 } }

      it 'evaluates the expression' do
        expect(evaluator.run).to eq('LESS')
      end
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
