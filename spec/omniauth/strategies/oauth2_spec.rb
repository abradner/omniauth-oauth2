require 'helper'

describe OmniAuth::Strategies::OAuth2 do
  def app
    lambda do |_env|
      [200, {}, ['Hello.']]
    end
  end
  let(:fresh_strategy) { Class.new(OmniAuth::Strategies::OAuth2) }

  before do
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = false
  end

  describe '#client' do
    subject { fresh_strategy }

    it 'is initialized with symbolized client_options' do
      instance = subject.new(app, :client_options => {'authorize_url' => 'https://example.com'})
      expect(instance.client.options[:authorize_url]).to eq('https://example.com')
    end

    it 'sets ssl options as connection options' do
      instance = subject.new(app, :client_options => {'ssl' => {'ca_path' => 'foo'}})
      expect(instance.client.options[:connection_opts][:ssl]).to eq(:ca_path => 'foo')
    end
  end

  describe '#authorize_params' do
    subject { fresh_strategy }

    it 'includes any authorize params passed in the :authorize_params option' do
      instance = subject.new('abc', 'def', :authorize_params => {:foo => 'bar', :baz => 'zip'})
      expect(instance.authorize_params['foo']).to eq('bar')
      expect(instance.authorize_params['baz']).to eq('zip')
    end

    it 'includes top-level options that are marked as :authorize_options' do
      instance = subject.new('abc', 'def', :authorize_options => [:scope, :foo, :state], :scope => 'bar', :foo => 'baz')
      expect(instance.authorize_params['scope']).to eq('bar')
      expect(instance.authorize_params['foo']).to eq('baz')
    end

    it 'includes random state in the authorize params' do
      instance = subject.new('abc', 'def')
      expect(instance.authorize_params.keys).to eq(['state'])
      expect(instance.session['omniauth.state']).not_to be_empty
    end
  end

  describe '#token_params' do
    subject { fresh_strategy }

    it 'includes any authorize params passed in the :authorize_params option' do
      instance = subject.new('abc', 'def', :token_params => {:foo => 'bar', :baz => 'zip'})
      expect(instance.token_params).to eq('foo' => 'bar', 'baz' => 'zip')
    end

    it 'includes top-level options that are marked as :authorize_options' do
      instance = subject.new('abc', 'def', :token_options => [:scope, :foo], :scope => 'bar', :foo => 'baz')
      expect(instance.token_params).to eq('scope' => 'bar', 'foo' => 'baz')
    end
  end

  describe '#callback_phase' do
    subject { fresh_strategy }
    it 'calls fail with the client error received' do
      instance = subject.new('abc', 'def')
      allow(instance).to receive(:request) do
        double('Request', :params => {'error_reason' => 'user_denied', 'error' => 'access_denied'})
      end

      expect(instance).to receive(:fail!).with('user_denied', anything)
      instance.callback_phase
    end

    it 'should accept callback params from the request via params[] hash' do

      # Fake having a session.
      # Can't use the ActionController:TestCase methods in this context
      OmniAuth::Strategies::OAuth2.class_eval %Q"
                                        def session=(var)
                                          @session = var
                                        end
                                        def session
                                          @session
                                        end
                                        "

      instance = subject.new('abc', 'def')
      allow(instance).to receive(:request) do
        double('Request', :params => {'code' => '4/def', 'state' => 'abc'})
      end

      instance.session = {'omniauth.state' => 'abc'}

      expect(instance).to receive(:build_access_token)

      # It will throw the exception because - as it stands - there is no way to actually successfully get
      # an access token back from the current build_access_token method without it coming from a proper request
      expect{
        instance.callback_phase
      }.to raise_error(
               NoMethodError,
               "undefined method `expired?' for nil:NilClass"
           )

    end

    it 'should accept callback params as arguments, not just from the request' do
      instance = subject.new('abc', 'def')

      # If everything in this method is working then it will call 'build_access_token'.
      # Not the best way to test it, but it's a good starting point before I modify any code
      expect(instance).to receive(:build_access_token)

      # It will throw the exception because - as it stands - there is no way to actually successfully get
      # an access token back from the current build_access_token method without it coming from a proper request
      expect{
        instance.callback_phase(:code => '4/def', :state => 'abc')
      }.to raise_error(
               NoMethodError,
               "undefined method `expired?' for nil:NilClass"
           )

    end


    it 'should, given sane params, return an access token' do
      instance = subject.new('abc', 'def')

      expect(
          instance.callback_phase(:code => '4/def', :state => 'abc')
      ).to be_a AccessToken

    end

  end
end

describe OmniAuth::Strategies::OAuth2::CallbackError do
  let(:error) { Class.new(OmniAuth::Strategies::OAuth2::CallbackError) }
  describe '#message' do
    subject { error }
    it 'includes all of the attributes' do
      instance = subject.new('error', 'description', 'uri')
      expect(instance.message).to match(/error/)
      expect(instance.message).to match(/description/)
      expect(instance.message).to match(/uri/)
    end
    it 'includes all of the attributes' do
      instance = subject.new(nil, :symbol)
      expect(instance.message).to eq('symbol')
    end
  end
end
