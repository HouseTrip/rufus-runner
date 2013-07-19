require 'spec_helper'

describe Rufus::TrackingScheduler do
  PID_DIR = Pathname.new 'tmp/pids'

  SCHEDULER_PID_FILE = PID_DIR.join('scheduler')

  CREATE_PID_WHEN_EM_STARTED = <<-RUBY
    # drop a file as soon as EventMachine has started
    # this lets us detect when we can start testing signals, for instance
    EventMachine.add_timer(1e-3) do
      Pathname.write_pid('#{SCHEDULER_PID_FILE}')
    end
  RUBY

  before do
    Pathname.glob(PID_DIR.join("*"), &:delete_if_exist)
  end

  let(:kill_file) { SCHEDULER_PID_FILE }

  shared_examples_for 'killable' do
    before do
      run_schedule
      wait_for_file kill_file or raise
    end

    it 'and finishes cleanly on SIGINT' do
      signal_schedule 'INT'
      wait_schedule.should == 0
    end

    it 'and finishes cleanly on SIGTERM' do
      signal_schedule 'TERM'
      wait_schedule.should == 0
    end

    it 'and does not leave child processes running' do
      signal_schedule 'INT'
      wait_schedule
      pids = Pathname.glob(PID_DIR.join('*')).collect do |f|
        File.read(f).to_i
      end
      pids -= [0, SCHEDULER_PID_FILE.read.to_i]
      pids = pids.select do |pid|
        process_running?(pid)
      end
      pids.should == []
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
          #{CREATE_PID_WHEN_EM_STARTED}
        end
      RUBY
    end

    it 'starts' do
      expect_new_file SCHEDULER_PID_FILE do
        run_schedule
      end
    end

    it_should_behave_like 'killable'
  end

  [:process, :thread].each do |fork_strategy|
    context "(using the :#{fork_strategy} fork strategy)" do

      context '(with simple jobs)' do
        let(:pid_job_1) { PID_DIR.join("job1") }
        let(:pid_job_2) { PID_DIR.join("job2") }
        let(:pid_job_3) { PID_DIR.join("job3") }

        before do |x|
          create_schedule <<-RUBY
            Rufus::TrackingScheduler.start(:timeout => 4, :fork => #{fork_strategy.inspect}) do |scheduler|
              scheduler.run :name => 'job_1', :every => '1s' do
                Pathname.write_pid('#{pid_job_1}')
              end

              scheduler.run :name => 'job_4', :every => '1s' do
                raise RuntimeError, 'fubar'
              end

              scheduler.run :name => 'job_2', :every => '1s' do
                Pathname.write_pid('#{pid_job_2}')
                Kernel.sleep 2
                Pathname.write_pid('#{pid_job_2}')
              end

              scheduler.run :name => 'job_3', :every => '1s' do
                Pathname.write_pid('#{pid_job_3}')
                Kernel.sleep 20
                Pathname.write_pid('#{pid_job_3}')
              end

              #{CREATE_PID_WHEN_EM_STARTED}
            end
          RUBY
        end

        it_should_behave_like 'killable'

        context '(when jobs are already running)' do
          let(:kill_file) { pid_job_3 }

          it_should_behave_like 'killable'
        end

        context '(considering job order)' do
          before do
            run_schedule
            wait_for_file SCHEDULER_PID_FILE or raise
          end
      
          it 'runs jobs' do
            wait_for_file(SCHEDULER_PID_FILE).should be_true
          end

          it 'waits for long-running jobs to complete' do
            # wait for job 2 to start
            wait_for_file(pid_job_2).should be_true
            pid_job_2.delete
            # ask scheduler to die
            signal_schedule 'TERM'
            # stamp file should reappear as job 2 completes
            wait_for_file(pid_job_2).should be_true
          end

          it 'does not run jobs in parallel' do
            wait_for_file(pid_job_2)
            pid_job_1.delete
            Kernel.sleep 1
            pid_job_1.should_not exist
          end

          it 'kills long-running jobs' do
            wait_for_file(pid_job_3)
            pid_job_3.delete
            signal_schedule 'TERM'
            wait_for_file(pid_job_3).should be_false
          end

          it 'logs jobs starting and ending' do
            wait_for_file(pid_job_2)
            scheduler_output.should =~ /job_1.*starting/
            scheduler_output.should =~ /job_1.*completed/
          end

          it 'logs jobs failing' do
            wait_for_file(pid_job_2)
            scheduler_output.should =~ /job_4.*starting/
            scheduler_output.should =~ /job_4.*failed/
          end
        end
      end

      context '(with jobs running only in some environments)' do
        let(:pid_job_1) { PID_DIR.join("job1") }
        let(:pid_job_2) { PID_DIR.join("job2") }
        let(:pid_job_3) { PID_DIR.join("job3") }
        let(:pid_job_4) { PID_DIR.join("job4") }
        let(:pid_job_5) { PID_DIR.join("job5") }

        before do
          create_schedule <<-RUBY
            Rufus::TrackingScheduler.start(:timeout => 4, :fork => #{fork_strategy.inspect}) do |scheduler|
              scheduler.run :name => 'job_1', :every => '1s' do
                Pathname.write_pid('#{pid_job_1}')
              end

              scheduler.run :name => 'job_2', :every => '1s', :environments => /some_environment/ do
                Pathname.write_pid('#{pid_job_2}')
              end

              scheduler.run :name => 'job_3', :every => '1s', :environments => /some_other_environment/ do
                Pathname.write_pid('#{pid_job_3}')
              end

              scheduler.run :name => 'job_4', :every => '1s', :environments => ["some_other_environment", "some_environment"] do
                Pathname.write_pid('#{pid_job_4}')
              end

              scheduler.run :name => 'job_5', :every => '1s', :environments => ["some_other_environment", /some_other_environment/] do
                Pathname.write_pid('#{pid_job_5}')
              end

              #{CREATE_PID_WHEN_EM_STARTED}
            end
          RUBY
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
            wait_for_file SCHEDULER_PID_FILE or raise
            wait_for_file(pid_job_1).should be_true
            wait_for_file(pid_job_2).should be_true
            wait_for_file(pid_job_3).should be_true
            wait_for_file(pid_job_4).should be_true
            wait_for_file(pid_job_5).should be_true
          end
        end

        context "(with environment 'some_environment')" do
          around do |example|
            with_environment('some_environment') { example.run }
          end

          it 'runs the generic job, and the jobs that mentions this environment' do
            run_schedule
            wait_for_file SCHEDULER_PID_FILE or raise
            wait_for_file(pid_job_1).should be_true
            wait_for_file(pid_job_2).should be_true
            wait_for_file(pid_job_4).should be_true
          end

          it 'does not run the jobs not mentioning this environment' do
            run_schedule
            wait_for_file SCHEDULER_PID_FILE or raise
            wait_for_file(pid_job_3).should be_false
            wait_for_file(pid_job_5).should be_false
          end
        end
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

    it 'uses a ForkingJobRunner by default' do
      runner = double('runner')
      Rufus::TrackingScheduler::ForkingJobRunner.should_receive(:new).and_return(runner)
      runner.should_receive(:run)
      subject.scheduler.stub(:every).and_yield(double('job'))
      subject.run(:every => 'period')
    end

    it 'uses a (non-forking) JobRunner when requested' do
      runner = double('runner')
      Rufus::TrackingScheduler::JobRunner.should_receive(:new).and_return(runner)
      runner.should_receive(:run)
      subject.scheduler.stub(:every).and_yield(double('job'))
      subject.run(:fork => :thread, :every => 'period')
    end
  end
end


