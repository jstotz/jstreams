RSpec.describe 'single subscriber' do
  it 'receives each published message once' do
    lines =
      IO.readlines(
        File.join(__dir__, '../fixtures/random-sorted-1000.txt'),
        chomp: true
      )

    jstreams = Jstreams::Context.new

    Thread.new do
      lines.each { |line| jstreams.publish('mystream', line) }
      jstreams.publish('mystream', '<end>')
    end

    results = []

    jstreams.subscribe(
      'mysubscriber',
      'mystream'
    ) do |message, _stream, subscriber|
      message == '<end>' ? subscriber.stop : results << message
    end

    Timeout.timeout(5) { jstreams.run }

    expect(results.sort).to eq(lines)
  end
end
