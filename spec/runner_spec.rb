require 'spec_helper'
require 'rufus-runner'

describe 'rufus-runner' do
  STAMP_FILE = Pathname.new 'tmp/stamp'

  CREATE_STAMP_WHEN_EM_STARTED = <<-RUBY
    # drop a timestamp as soon as EventMachine has started
    # this lets us detect when we can start testing signals, for instance
    EventMachine.add_timer(1e-3) do
      Pathname.timestamp('#{STAMP_FILE}')
    end
  RUBY

  after do
    STAMP_FILE.delete_if_exist
  end

  shared_examples_for 'killable' do
    before do
      run_schedule
      wait_for_file STAMP_FILE or raise
    end

    it 'finishes cleanly on SIGINT' do
      signal_schedule 'INT'
      wait_schedule.should == 0
    end

    it 'finishes cleanly on SIGTERM' do
      signal_schedule 'TERM'
      wait_schedule.should == 0
    end
  end


  context '(without a schedule)' do
    it 'exits with error' do
      raise 'this should not happen' if ScheduleHelper::TEST_SCHEDULE.exist?
      run_schedule
      wait_schedule.should_not == 0
    end
  end

  context '(with a bad schedule)' do
    before do
      create_schedule <<-RUBY
        this is English, not ruby
      RUBY
    end

    it 'exits with error' do
      run_schedule
      wait_schedule.should_not == 0
    end
  end

  context '(with an empty schedule)' do
    before do
      create_schedule <<-RUBY
        Rufus::TrackingScheduler.start do |scheduler|
          #{CREATE_STAMP_WHEN_EM_STARTED}
        end
      RUBY
    end

    it 'starts' do
      expect_new_file STAMP_FILE do
        run_schedule
      end
    end

    it_should_behave_like 'killable'
  end

  context '(with simple jobs)' do
    let(:stamp_job_1) { Pathname.new('tmp/stamp1') }
    let(:stamp_job_2) { Pathname.new('tmp/stamp2') }
    let(:stamp_job_3) { Pathname.new('tmp/stamp3') }

    before do
      create_schedule <<-RUBY
        Rufus::TrackingScheduler.start(:timeout => 4) do |scheduler|
          scheduler.run :name => 'job_1', :every => '1s' do
            Pathname.timestamp('#{stamp_job_1}')
          end

          scheduler.run :name => 'job_4', :every => '1s' do
            raise RuntimeError, 'fubar'
          end

          scheduler.run :name => 'job_2', :every => '1s' do
            Pathname.timestamp('#{stamp_job_2}')
            Kernel.sleep 2
            Pathname.timestamp('#{stamp_job_2}')
          end

          scheduler.run :name => 'job_3', :every => '1s' do
            Pathname.timestamp('#{stamp_job_3}')
            Kernel.sleep 60
            Pathname.timestamp('#{stamp_job_3}')
          end

          #{CREATE_STAMP_WHEN_EM_STARTED}
        end
      RUBY
    end

    after do
      stamp_job_1.delete_if_exist
      stamp_job_2.delete_if_exist
      stamp_job_3.delete_if_exist
    end

    it_should_behave_like 'killable'

    context '(considering job order)' do
      before do
        run_schedule
        wait_for_file STAMP_FILE or raise
      end
  
      it 'runs jobs' do
        wait_for_file(STAMP_FILE).should be_true
      end

      it 'waits for long-running jobs to complete' do
        # wait for job 2 to start
        wait_for_file(stamp_job_2).should be_true
        stamp_job_2.delete
        # ask scheduler to die
        signal_schedule 'TERM'
        # stamp file should reappear as job 2 completes
        wait_for_file(stamp_job_2).should be_true
      end

      it 'does not run jobs in parallel' do
        wait_for_file(stamp_job_2)
        stamp_job_1.delete
        Kernel.sleep 1
        stamp_job_1.should_not exist
      end

      it 'kills long-running jobs' do
        wait_for_file(stamp_job_3)
        stamp_job_3.delete
        signal_schedule 'TERM'
        wait_for_file(stamp_job_3).should be_false
      end

      it 'logs jobs starting and ending' do
        wait_for_file(stamp_job_2)
        scheduler_output.should =~ /job_1.*starting/
        scheduler_output.should =~ /job_1.*completed/
      end

      it 'logs jobs failing' do
        wait_for_file(stamp_job_2)
        scheduler_output.should =~ /job_4.*starting/
        scheduler_output.should =~ /job_4.*failed/
      end
    end
  end

  context '(with jobs running only in some environments)' do
    let(:stamp_job_1) { Pathname.new('tmp/stamp1') }
    let(:stamp_job_2) { Pathname.new('tmp/stamp2') }
    let(:stamp_job_3) { Pathname.new('tmp/stamp3') }
    let(:stamp_job_4) { Pathname.new('tmp/stamp4') }
    let(:stamp_job_5) { Pathname.new('tmp/stamp5') }

    before do
      create_schedule <<-RUBY
        Rufus::TrackingScheduler.start(:timeout => 4) do |scheduler|
          scheduler.run :name => 'job_1', :every => '1s' do
            Pathname.timestamp('#{stamp_job_1}')
          end

          scheduler.run :name => 'job_2', :every => '1s', :environments => /some_environment/ do
            Pathname.timestamp('#{stamp_job_2}')
          end

          scheduler.run :name => 'job_3', :every => '1s', :environments => /some_other_environment/ do
            Pathname.timestamp('#{stamp_job_3}')
          end

          scheduler.run :name => 'job_4', :every => '1s', :environments => ["some_other_environment", "some_environment"] do
            Pathname.timestamp('#{stamp_job_4}')
          end

          scheduler.run :name => 'job_5', :every => '1s', :environments => ["some_other_environment", /some_other_environment/] do
            Pathname.timestamp('#{stamp_job_5}')
          end

          #{CREATE_STAMP_WHEN_EM_STARTED}
        end
      RUBY
    end

    after do
      stamp_job_1.delete_if_exist
      stamp_job_2.delete_if_exist
      stamp_job_3.delete_if_exist
      stamp_job_4.delete_if_exist
      stamp_job_5.delete_if_exist
    end


    def with_environment(env, &block)
      begin
        old_env = ENV['RAILS_ENV']
        ENV['RAILS_ENV'] = env
        yield
      ensure
        ENV['RAILS_ENV'] = old_env
      end
    end

    context "(with no rails environment)" do
      around do |example|
        with_environment(nil) { example.run }
      end

      it 'runs all the jobs' do
        run_schedule
        wait_for_file STAMP_FILE or raise
        wait_for_file(stamp_job_1).should be_true
        wait_for_file(stamp_job_2).should be_true
        wait_for_file(stamp_job_3).should be_true
        wait_for_file(stamp_job_4).should be_true
        wait_for_file(stamp_job_5).should be_true
      end
    end

    context "(with environment 'some_environment')" do
      around do |example|
        with_environment('some_environment') { example.run }
      end

      it 'runs the generic job, and the jobs that mentions this environment' do
        run_schedule
        wait_for_file STAMP_FILE or raise
        wait_for_file(stamp_job_1).should be_true
        wait_for_file(stamp_job_2).should be_true
        wait_for_file(stamp_job_4).should be_true
      end

      it 'does not run the jobs not mentioning this environment' do
        run_schedule
        wait_for_file STAMP_FILE or raise
        wait_for_file(stamp_job_3).should be_false
        wait_for_file(stamp_job_5).should be_false
      end
    end
  end

  describe '#run' do

    subject do
      Class.new(Rufus::TrackingScheduler) do
        attr_reader :scheduler
        def log(string)
        end
      end.new
    end

    it 'delegates to scheduler.every if the :every option is given' do
      subject.scheduler.should_receive(:every).with('period', anything)
      subject.run(:every => 'period')
    end

    it 'delegates to scheduler.cron if the :cron option is given' do
      subject.scheduler.should_receive(:cron).with('c r o n * *', anything)
      subject.run(:cron => 'c r o n * *')
    end

    it 'raises an ArgumentError if neither :every nor :cron is given' do
      proc do
        subject.run
      end.should raise_error(ArgumentError)
    end
  end
end


