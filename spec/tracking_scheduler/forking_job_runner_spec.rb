require 'spec_helper'

unless defined?(ActiveRecord)
  module ActiveRecord
    class Base
      def self.clear_active_connections!
      end
    end
  end
end


describe Rufus::TrackingScheduler::ForkingJobRunner do

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

  def run_and_return(&block)
    get_from_other_process do |pipe|
      run do
        pipe.return(block.call)
      end
    end
  end

  def have_child_processes_finished?
    Process.wait(-1, Process::WNOHANG)
    false
  rescue Errno::ECHILD
    true
  end


  describe '#run' do

    it 'runs the block' do
      run_and_return { "called" }.should == "called"
    end

    it 'does not run the block if we\'re shutting down' do
      scheduler.stub :shutting_down? => true
      block_called = false
      run_and_return { "called" }.should_not == "called"
    end

    it 'runs the block in another process' do
      run_and_return { Process.pid }.should_not == Process.pid
    end

    it 'waits for the process to end' do
      wait_for_child_processes # possibly left over from earlier tests
      run { sleep 0.1 }
      have_child_processes_finished?.should be_true
    end

    it 'resets active ActiveRecord connections' do
      ActiveRecord::Base.should_receive(:clear_active_connections!)
      run {}
    end

    context '(timeouts)' do

      def run_and_timeout(timeout, &block)
        result = nil
        thread = Thread.new do
          result = run_and_return do
            block.call
          end
        end
        Thread.new do
          sleep timeout
          thread.raise(Rufus::Scheduler::TimeOutError.new) rescue nil
        end
        thread.join
        result
      end

      it 'returns after the timeout' do
        start = Time.now
        run_and_timeout(0.1) do
          sleep 2
        end
        (Time.now - start).should < 0.5
      end

      it 'kills the child process' do
        wait_for_child_processes # possibly left over from earlier tests
        run_and_timeout(0.1) do
          sleep 2
        end
        have_child_processes_finished?.should be_true
      end

      it 'lets the block finish regularly if the timeout is longer' do
        result = run_and_timeout(2) do
          sleep 0.1
          "done"
        end
        result.should == "done"
      end

      it 'does not wait for the timeout period if the block finishes quicker' do
        start = Time.now
        run_and_timeout(2) do
          sleep 0.1
        end
        (Time.now - start).should < 0.5
      end

    end

  end

end
