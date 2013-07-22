require 'rufus-runner/tracking_scheduler/job_runner'

class Rufus::TrackingScheduler::ThreadingJobRunner < Rufus::TrackingScheduler::JobRunner

  def shutdown
    # nothing to do, threads will die automatically
  end


  private

  def run_block
    @block.call
  end

end
