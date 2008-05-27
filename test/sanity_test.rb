require File.dirname(__FILE__) + "/help"

describe 'The Top Level' do
  
  [ :environment, :production?, :development?, :reloading? ].each do |meth|
    it "responds to :#{meth}" do
      Object.private_methods.map{ |s| s.to_sym }.should.include(meth)
    end
  end

  it 'responds with the Sinatra environment when sent :environment' do
    environment.should.not.be.nil
    environment.should.equal Sinatra.application.options.env.to_sym
    environment.should.be == :test
  end

end

describe 'String' do

  it 'responds to blank?' do
    [ '', nil, [], {} ].each do |o|
      o.should.respond_to :blank?
      o.blank?.should.be true
    end
    [ 0, ['hi'], { :a => 1 } ].each do |o|
      o.should.respond_to :blank?
      o.blank?.should.be false
    end
  end

end

describe 'Sinatra' do

  it 'should not have reloading enabled in test environment' do
    reloading?.should.not.be.truthful
  end

  it 'should not have automatic server running enabled' do
    Sinatra.application.options.run.should.not.be.truthful
  end

end
