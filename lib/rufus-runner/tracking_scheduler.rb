class Rufus::TrackingScheduler
end

require 'rufus/scheduler'
require 'eventmachine'
require 'rufus-runner/tracking_scheduler/threading_job_runner'
require 'rufus-runner/tracking_scheduler/forking_job_runner'

#
# Wraps Rufus's scheduler class with signal handling,
# cancellation of jobs, and logging.
#
class Rufus::TrackingScheduler
  # wait that long for jobs to complete before quitting (seconds)
  GRACE_DELAY = 10

  def initialize(options = {})
    @options = DefaultOptions.merge(options)
    @scheduler = Rufus::Scheduler::EmScheduler.start_new
    log('scheduler started')
  end

  def run(options={}, &block)
    return unless rails_environment_matches?(options.delete(:environments))
    options = options.merge(@options)

    name = options.delete(:name) || 'noname'
    case options.delete(:fork) || :thread
    when :thread
      job_runner_class = ThreadingJobRunner
    when :process
      job_runner_class = ForkingJobRunner
    else
      fail ArgumentError.new("option :fork needs to be either :thread or :process")
    end

    schedule(options) do |job|
      job_runner = job_runner_class.new(
        :name => name,
        :job => job,
        :block => block,
        :scheduler => self
      )
      job_runner.run
    end

    log("scheduled '#{name}'")
    nil
  end

  def self.start(options = {})
    EM.run do
      scheduler = new(options)
      scheduler.send :setup_traps
      yield scheduler
    end
  end

  def shutting_down!
    @shutting_down = true
  end

  def shutting_down?
    !!@shutting_down
  end


  def log(string)
    $stdout.puts "[#{$PROGRAM_NAME} #{format_time Time.now}] #{string}"
    $stdout.flush
  end

  private

  def schedule(options, &block)
    if frequency = options.delete(:every)
      scheduling_method = :every
    elsif frequency = options.delete(:cron)
      scheduling_method = :cron
    else
      raise ArgumentError.new('You need to specify either :every or :cron')
    end

    @scheduler.send(scheduling_method, frequency, options, &block)
  end

  def setup_traps
    %w(INT TERM).each do |signal|
      Signal.trap(signal) do
        log "SIG#{signal} received"
        stop_all_jobs
        EM.stop_event_loop
      end
    end
  end

  def stop_all_jobs
    shutting_down!
    @scheduler.jobs.each_pair do |job_id, job|
      job.unschedule
    end
    log "all jobs unscheduled"
    if running_jobs_count == 0
      log "no more jobs running"
      return
    end

    log "waiting for #{running_jobs_count} still running jobs"
    start_time = Time.now
    while (Time.now <= start_time + GRACE_DELAY) && (running_jobs_count > 0)
      Kernel.sleep(100e-3)
    end

    if running_jobs_count > 0
      log "#{running_jobs_count} jobs did not complete"
      @scheduler.running_jobs.collect(&:job_runner).each(&:shutdown)
    else
      log "all jobs completed"
    end
  end

  def running_jobs_count
    @scheduler.running_jobs.length
  end

  def format_time(time)
    "%s.%03d" % [time.strftime('%F %T'), ((time.to_f - time.to_i) * 1e3).to_i]
  end

  def rails_environment_matches?(environments)
    return true unless rails_environment
    return true if environments.nil?

    Array(environments).any? do |environment|
      # environment can be a string or a regexp
      environment === rails_environment
    end
  end

  def rails_environment
    if defined?(Rails)
      Rails.env
    else
      ENV['RAILS_ENV'] || ENV['RACK_ENV']
    end
  end

  DefaultOptions = {
    :fork              => :process,  # safety first
    :mutex             => Mutex.new, # because Rails is not thread-safe
    :timeout           => 60,        # we don't want no long-running jobs, they should be DJ'd (seconds)
    :discard_past      => true,      # don't catch up with past jobs
    :allow_overlapping => false,     # don't try to run the same job twice simultaneously
  }
end
