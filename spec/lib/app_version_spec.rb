require 'app_version'

describe AppVersion do
  describe '.current' do
    subject(:current) { described_class.current(env) }

    context 'when COMMIT_VERSION is set' do
      let(:env) { { 'COMMIT_VERSION' => 'v0.10.1-3-g2d8f177', 'VERSION' => 'develop' } }

      it { is_expected.to eq('v0.10.1-3-g2d8f177') }
    end

    context 'when COMMIT_VERSION is blank' do
      let(:env) { { 'COMMIT_VERSION' => '', 'VERSION' => 'develop' } }

      it 'falls back to VERSION' do
        expect(current).to eq('develop')
      end
    end

    context 'when both are blank' do
      let(:env) { { 'COMMIT_VERSION' => '', 'VERSION' => '' } }

      it { is_expected.to be_nil }
    end

    context 'when both are unset' do
      let(:env) { {} }

      it { is_expected.to be_nil }
    end
  end
end
