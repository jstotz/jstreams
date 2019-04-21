# frozen_string_literal: true

RSpec.describe 'consumer group creation' do
  before(:each) { redis.flushdb }
  after(:each) { jstreams.shutdown }

  let(:jstreams) { Jstreams::Context.new }
  let(:redis) { Redis.new }

  context 'when the consumer group does not exist' do
    it 'creates a new stream and consumer group on start' do
      jstreams.publish('mystream', 'foo')
      expect(redis.xinfo(:groups, 'mystream')).to eq([])
      jstreams.subscribe('mygroup', 'mystream') { |_, _, s| s.stop }
      Timeout.timeout(5) { jstreams.run }
      expect(redis.xinfo(:groups, 'mystream').map { |g| g['name'] }).to eq(
            %w[mygroup]
          )
    end
  end

  context 'when the consumer group already exists' do
    it 'does nothing' do
      redis.xgroup(:create, 'mystream', 'mygroup', 0, mkstream: true)
      jstreams.publish('mystream', 'foo')
      expect(redis.xinfo(:groups, 'mystream').map { |g| g['name'] }).to eq(
            %w[mygroup]
          )
      jstreams.subscribe('mygroup', 'mystream') { |_, _, s| s.stop }
      Timeout.timeout(5) { jstreams.run }
      expect(redis.xinfo(:groups, 'mystream').map { |g| g['name'] }).to eq(
            %w[mygroup]
          )
    end
  end
end
