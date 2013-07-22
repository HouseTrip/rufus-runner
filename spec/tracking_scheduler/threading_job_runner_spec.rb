require 'spec_helper'

unless defined?(ActiveRecord::Base.clear_active_connections!)
  module ActiveRecord
    class Base
      def self.clear_active_connections!
      end
    end
  end
end

unless defined?(ActiveRecord::ConnectionTimeoutError)
  module ActiveRecord
    class ConnectionTimeoutError < StandardError; end
  end
end


describe Rufus::TrackingScheduler::ThreadingJobRunner do

  let(:name) { "some job" }
  let(:job) { double('job', :job_id => '1234', :job_runner= => nil) }
  let(:scheduler) { double('scheduler', :log => nil, :shutting_down? => false) }

  def job_runner(&block)
    described_class.new(
      :name => name,
      :job => job,
      :scheduler => scheduler,
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

    it 'does not run the block if we\'re shutting down' do
      scheduler.stub :shutting_down? => true
      block_called = false
      run do
        block_called = true
      end
      block_called.should be_false
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
