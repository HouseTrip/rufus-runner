class Rufus::TrackingScheduler::JobRunner

  def initialize(options)
    @name = options.fetch(:name)
    @job = options.fetch(:job)
    @block = options.fetch(:block)
    @logger = options.fetch(:logger)
  end

  def run
    start_time = Time.now
    log("starting")

    begin
      run_block
    rescue Exception => exception
      log("failed with #{exception.class.name} (#{exception.message})")
      if defined?(ActiveRecord::ConnectionTimeoutError) && exception.kind_of?(ActiveRecord::ConnectionTimeoutError)
        log("connection broken, exiting scheduler")
        exit 0
      end
    else
      total_time = Time.now - start_time
      log("completed in %.3f s" % total_time)
    end

    if defined?(ActiveRecord::Base)
      ActiveRecord::Base.clear_active_connections!
    end
  end


  private

  def run_block
    @block.call
  end

  def job_id
    @job_id ||= '%08x' % @job.job_id.gsub(/\D/,'')
  end

  def log(message)
    @logger.log("#{@name}(#{job_id}): #{message}")
  end

end
