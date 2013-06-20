require 'rufus/scheduler'
require 'eventmachine'

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
    name  = options.delete(:name) || 'noname'
    if frequency = options.delete(:every)
      scheduling_method = :every
    elsif frequency = options.delete(:cron)
      scheduling_method = :cron
    else
      raise ArgumentError.new('You need to specify either :every or :cron')
    end

    @scheduler.send(scheduling_method, frequency, @options.merge(options)) do |job|
      job_id = '%08x' % job.job_id.gsub(/\D/,'')
      start_time = Time.now
      log("#{name}(#{job_id}): starting")

      begin
        block.call
      rescue Exception => exception
        log("#{name}(#{job_id}): failed with #{exception.class.name} (#{exception.message})")
        if exception.kind_of? ActiveRecord::ConnectionTimeoutError
          log("connection broken, exiting scheduler")
          exit 0
        end
      else
        total_time = Time.now - start_time
        log("#{name}(#{job_id}): completed in %.3f s" % total_time)
      end
      
      if defined?(ActiveRecord::Base)
        ActiveRecord::Base.clear_active_connections!
      end
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

  private

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
    else
      log "all jobs completed"
    end
  end

  def running_jobs_count
    @scheduler.running_jobs.length
  end

  def log(string)
    $stdout.puts "[#{$PROGRAM_NAME} #{format_time Time.now}] #{string}"
    $stdout.flush
  end

  def format_time(time)
    "%s.%03d" % [time.strftime('%F %T'), ((time.to_f - time.to_i) * 1e3).to_i]
  end

  DefaultOptions = {
    :mutex             => Mutex.new, # because Rails is not thread-safe
    :timeout           => 60,        # we don't want no long-running jobs, they should be DJ'd (seconds)
    :discard_past      => true,      # don't catch up with past jobs
    :allow_overlapping => false,     # don't try to run the same job twice simultaneously
  }
end
