require 'spec_helper'

unless defined?(ActiveRecord)
  module ActiveRecord
    class Base
      def self.clear_active_connections!
      end
    end

    class ConnectionTimeoutError < StandardError; end
  end
end


describe Rufus::TrackingScheduler::JobRunner do

  let(:name) { "some job" }
  let(:job) { double('job', :job_id => '1234') }
  let(:logger) { double('logger', :log => nil) }

  def job_runner(&block)
    described_class.new(
      :name => name,
      :job => job,
      :logger => logger,
      :block => block
    )
  end

  def run(&block)
    job_runner(&block).run
  end

  describe '#run' do

    it 'runs the block' do
      block_called = false
      run do
        block_called = true
      end
      block_called.should be_true
    end

    it 'resets active ActiveRecord connections' do
      ActiveRecord::Base.should_receive(:clear_active_connections!)
      run {}
    end

    it 'exits the scheduler on ActiveRecord::ConnectionTimeoutErrors' do
      job_runner = job_runner do
        raise ActiveRecord::ConnectionTimeoutError.new
      end
      job_runner.should_receive(:exit).with(0)
      job_runner.run
    end

  end

end
