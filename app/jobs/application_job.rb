class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # Report all job errors to Rollbar
  rescue_from StandardError do |exception|
    Rollbar.error(exception, job: self.class.name, arguments: arguments)
    raise exception
  end
end
