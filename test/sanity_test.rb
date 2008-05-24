require File.dirname(__FILE__) + "/help"

context 'a basic wink environment' do

  specify 'top level objects should be defined' do
    Object.should.const_defined 'Weblog'
    Object.should.const_defined 'Entry'
    Object.should.const_defined 'Bookmark'
  end

  specify 'environment detection should be present' do
    Object.private_methods.should.include 'environment'
    environment.should.equal :test
  end

  specify 'top level helper methods should exist for environment detection' do
    %w[development? production?].each do |method|
      Object.private_methods.should.include method
    end
  end

  specify 'reloading in test environment should be disabled' do
    Object.private_methods.should.include 'reloading?'
    reloading?.should.not.be true
  end

  specify 'automatic server running should be disabled' do
    Sinatra.application.options.run.should.not.be true
  end

end
